using ZMQ, Test

@info("Testing with ZMQ version $(ZMQ.version)")

@testset "ZMQ contexts" begin
	ctx=Context()
	@test ctx isa Context
	@test (ctx.io_threads = 2) == 2
	@test ctx.io_threads == 2
	ZMQ.close(ctx)

	#try to create socket with expired context
	@test_throws StateError Socket(ctx, PUB)
end

@testset "ZMQ sockets" begin
	s=Socket(PUB)
	@test s isa Socket
	ZMQ.close(s)

	s1=Socket(REP)
	s1.sndhwm = 1000
	s1.linger = 1
	s1.routing_id = "abcd"

	@test s1.routing_id == "abcd"
	@test s1.sndhwm === 1000
	@test s1.linger === 1
	@test s1.rcvmore === false

	s2=Socket(REQ)
	@test s1.type == REP
	@test s2.type == REQ

	ZMQ.bind(s1, "tcp://*:5555")
	ZMQ.connect(s2, "tcp://localhost:5555")

	msg = Message("test request")

    # Smoke tests
    @test Base.elsize(msg) == 1
    @test Base.strides(msg) == (1,)

	# Test similar() and copy() fixes in https://github.com/JuliaInterop/ZMQ.jl/pull/165
	# Note that we have to send this message to work around
	# https://github.com/JuliaInterop/ZMQ.jl/issues/166
	@test similar(msg, UInt8, 12) isa Vector{UInt8}
	@test copy(msg) == codeunits("test request")
	ZMQ.send(s2, msg)
	@test unsafe_string(ZMQ.recv(s1)) == "test request"
	ZMQ.send(s1, Message("test response"))
	@test unsafe_string(ZMQ.recv(s2)) == "test response"

	ZMQ.send(s2, "test request 2")
	@test ZMQ.recv(s1, String) == "test request 2"
	ZMQ.send(s1, Vector(codeunits("test response 2")))
	@test String(ZMQ.recv(s2, Vector{UInt8})) == "test response 2"
	ZMQ.send(s2, 3.14159)
	@test ZMQ.recv(s1, Float64) === 3.14159
	ZMQ.send(s1, [314159, 12345])
	@test ZMQ.recv(s2, Vector{Int}) == [314159, 12345]

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

	# Test _Message task-blocking behavior, similar to above
	c = Base.Condition()
	msg_sent = false
	@async begin
		global msg_sent
		sleep(0.5)
		msg_sent = true
		ZMQ.send(s2, "another test request")
		@test ZMQ.recv(s2, String) == "another test response"
		notify(c)
	end
	@test ZMQ.recv(s1, String) == "another test request"
	@test msg_sent == true
	ZMQ.send(s1, "another test response")
	wait(c)

	ZMQ.send(s2, Message("another test request"))
	msg = ZMQ.recv(s1)
	o=convert(IOStream, msg)
	seek(o, 0)
	@test String(take!(o)) == "another test request"
	ZMQ.send(s1) do io
		print(io, "buffer ")
		print(io, "this")
	end
	@test String(take!(ZMQ.recv(s2, IOBuffer))) == "buffer this"

	@testset "Message AbstractVector interface" begin
		m = Message("1")
		@test m[1]==0x31
		@test (m[1]=0x32) === 0x32
		@test unsafe_string(m)=="2"
		finalize(m)
	end

	# ZMQ.close(s1); ZMQ.close(s2) # should happen when context is closed
	ZMQ.close(ZMQ._context) # immediately close global context rather than waiting for exit
end

@testset "ZMQ resource management" begin
    local leaked_req_socket, leaked_rep_socket
    ZMQ.Socket(ZMQ.REQ) do req_socket
	leaked_req_socket = req_socket

	ZMQ.Socket(ZMQ.REP) do rep_socket
	    leaked_rep_socket = rep_socket

	    ZMQ.bind(rep_socket, "inproc://tester")
	    ZMQ.connect(req_socket, "inproc://tester")

	    ZMQ.send(req_socket, "Mr. Watson, come here, I want to see you.")
	    @test unsafe_string(ZMQ.recv(rep_socket)) == "Mr. Watson, come here, I want to see you."
	    ZMQ.send(rep_socket, "Coming, Mr. Bell.")
	    @test unsafe_string(ZMQ.recv(req_socket)) == "Coming, Mr. Bell."
	end

	@test !ZMQ.isopen(leaked_rep_socket)
    end
    @test !ZMQ.isopen(leaked_req_socket)

    local leaked_ctx
    ZMQ.Context() do ctx
	leaked_ctx = ctx

	@test isopen(ctx)
    end
    @test !isopen(leaked_ctx)
end
