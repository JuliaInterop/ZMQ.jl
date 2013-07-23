require("ZMQ")
using ZMQ

println("Testing with ZMQ version $(ZMQ.version)")

ctx=Context(1)

@assert typeof(ctx) == Context

ZMQ.close(ctx)

#try to create socket with expired context
try 
	Socket(ctx, PUB)
	@assert false
catch ex
	@assert typeof(ex) == StateError
end


ctx2=Context(1)
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
if ZMQ.version.major == 2 
	ZMQ.set_hwm(s1, 1000)
else 
	ZMQ.set_sndhwm(s1, 1000)
end
ZMQ.set_linger(s1, 1)
ZMQ.set_identity(s1, "abcd")


@assert ZMQ.get_identity(s1)::String == "abcd"
if ZMQ.version.major == 2
	@assert ZMQ.get_hwm(s1)::Integer == 1000
else
	@assert ZMQ.get_sndhwm(s1)::Integer == 1000
end
@assert ZMQ.get_linger(s1)::Integer == 1
@assert ZMQ.ismore(s1) == false 

s2=Socket(ctx2, REQ)
@assert ZMQ.get_type(s1) == REP 
@assert ZMQ.get_type(s2) == REQ 

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

ZMQ.send(s2, Message("test request"))
@assert (bytestring(ZMQ.recv(s1)) == "test request")
ZMQ.send(s1, Message("test response"))
@assert (bytestring(ZMQ.recv(s2)) == "test response")

ZMQ.send(s2, Message("another test request"))
msg = ZMQ.recv(s1)
o=convert(IOStream, msg)
seek(o, 0)
@assert (takebuf_string(o)=="another test request")

#ZMQ.close(s1)
#ZMQ.close(s2)
ZMQ.close(ctx2)






