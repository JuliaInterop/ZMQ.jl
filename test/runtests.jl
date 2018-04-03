using ZMQ, Compat

println("Testing with ZMQ version $(ZMQ.version)")

ctx=Context()

@assert typeof(ctx) == Context

ZMQ.close(ctx)

#try to create socket with expired context
try
	Socket(ctx, PUB)
	@assert false
catch ex
	@assert typeof(ex) == StateError
end


ctx2=Context()
s=Socket(ctx2, PUB)
@assert typeof(s) == Socket
ZMQ.close(s)

#trying to close already closed socket
try
	ZMQ.close(s)
catch ex
	@assert typeof(ex) == StateError
end


s1=Socket(ctx2, REP)
ZMQ.set_sndhwm(s1, 1000)
ZMQ.set_linger(s1, 1)
ZMQ.set_identity(s1, "abcd")


@assert ZMQ.get_identity(s1)::AbstractString == "abcd"
@assert ZMQ.get_sndhwm(s1)::Integer == 1000
@assert ZMQ.get_linger(s1)::Integer == 1
@assert ZMQ.ismore(s1) == false

s2=Socket(ctx2, REQ)
@assert ZMQ.get_type(s1) == REP
@assert ZMQ.get_type(s2) == REQ

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

msg = Message("test request")
# Test similar() and copy() fixes in https://github.com/JuliaInterop/ZMQ.jl/pull/165
# Note that we have to send this message to work around
# https://github.com/JuliaInterop/ZMQ.jl/issues/166
@assert similar(msg, UInt8, 12) isa Vector{UInt8}
@assert copy(msg) == convert(Vector{UInt8}, "test request")
ZMQ.send(s2, msg)
@assert (unsafe_string(ZMQ.recv(s1)) == "test request")
ZMQ.send(s1, Message("test response"))
@assert (unsafe_string(ZMQ.recv(s2)) == "test response")

# Test task-blocking behavior
c = Base.Condition()
msg_sent = false
@async begin
	global msg_sent
	sleep(0.5)
	msg_sent = true
	ZMQ.send(s2, Message("test request"))
	@assert (unsafe_string(ZMQ.recv(s2)) == "test response")
	notify(c)
end

# This will hang forver if ZMQ blocks the entire process since
# we'll never switch to the other task
@assert (unsafe_string(ZMQ.recv(s1)) == "test request")
@assert msg_sent == true
ZMQ.send(s1, Message("test response"))
wait(c)

ZMQ.send(s2, Message("another test request"))
msg = ZMQ.recv(s1)
o=convert(IOStream, msg)
seek(o, 0)
@assert (String(take!(o))=="another test request")

ZMQ.close(s1)
ZMQ.close(s2)
ZMQ.close(ctx2)
