using ZMQ, Test

@info("Testing with ZMQ version $(ZMQ.version)")

@testset "ZMQ sockets" begin
	ctx=Context()
	@test ctx isa Context
	ZMQ.close(ctx)

	#try to create socket with expired context
	@test_throws StateError Socket(ctx, PUB)

	s=Socket(PUB)
	@test s isa Socket
	ZMQ.close(s)

	s1=Socket(REP)
	ZMQ.set_sndhwm(s1, 1000)
	ZMQ.set_linger(s1, 1)
	ZMQ.set_identity(s1, "abcd")

	@test ZMQ.get_identity(s1)::AbstractString == "abcd"
	@test ZMQ.get_sndhwm(s1)::Integer == 1000
	@test ZMQ.get_linger(s1)::Integer == 1
	@test ZMQ.ismore(s1) == false

	s2=Socket(REQ)
	@test ZMQ.get_type(s1) == REP
	@test ZMQ.get_type(s2) == REQ

	ZMQ.bind(s1, "tcp://*:5555")
	ZMQ.connect(s2, "tcp://localhost:5555")

	msg = Message("test request")
	# Test similar() and copy() fixes in https://github.com/JuliaInterop/ZMQ.jl/pull/165
	# Note that we have to send this message to work around
	# https://github.com/JuliaInterop/ZMQ.jl/issues/166
	@test similar(msg, UInt8, 12) isa Vector{UInt8}
	@test copy(msg) == codeunits("test request")
	ZMQ.send(s2, msg)
	@test unsafe_string(ZMQ.recv(s1)) == "test request"
	ZMQ.send(s1, Message("test response"))
	@test unsafe_string(ZMQ.recv(s2)) == "test response"

	# Test task-blocking behavior
	c = Base.Condition()
	global msg_sent = false
	@async begin
		global msg_sent
		sleep(0.5)
		msg_sent = true
		ZMQ.send(s2, Message("test request"))
		@test (unsafe_string(ZMQ.recv(s2)) == "test response")
		notify(c)
	end

	# This will hang forver if ZMQ blocks the entire process since
	# we'll never switch to the other task
	@test unsafe_string(ZMQ.recv(s1)) == "test request"
	@test msg_sent == true
	ZMQ.send(s1, Message("test response"))
	wait(c)

	ZMQ.send(s2, Message("another test request"))
	msg = ZMQ.recv(s1)
	o=convert(IOStream, msg)
	seek(o, 0)
	@test String(take!(o)) == "another test request"

	@testset "Message AbstractVector interface" begin
		m = Message("1")
		@test m[1]==0x31
		m[1]=0x32
		@test unsafe_string(m)=="2"
		finalize(m)
	end

	# ZMQ.close(s1); ZMQ.close(s2) # should happen when context is closed
	ZMQ.close(ZMQ._context) # immediately close global context rather than waiting for exit
end
