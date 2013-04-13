require("ZMQ")
using ZMQ

println("Testing with ZMQ version $(ZMQ.version())")
@assert length(ZMQ.version()) == 3

major, minor, patch = ZMQ.version()

ctx=ZMQContext(1)

@assert typeof(ctx) == ZMQContext

ZMQ.close(ctx)

#try to create socket with expired context
try 
	ZMQSocket(ctx, ZMQ_PUB)
	@assert false
catch ex
	@assert typeof(ex) == ZMQStateError
end


ctx2=ZMQContext(1)
s=ZMQSocket(ctx2, ZMQ_PUB)
@assert typeof(s) == ZMQSocket
ZMQ.close(s)

#trying to close already closed socket
try 
	ZMQ.close(s)
catch ex
	@assert typeof(ex) == ZMQStateError
end


s1=ZMQSocket(ctx2, ZMQ_REP)
if major == 2 
	ZMQ.set_hwm(s1, 1000)
else 
	ZMQ.set_sndhwm(s1, 1000)
end
ZMQ.set_linger(s1, 1)
ZMQ.set_identity(s1, "abcd")


@assert ZMQ.get_identity(s1)::String == "abcd"
if major == 2
	@assert ZMQ.get_hwm(s1)::Integer == 1000
else
	@assert ZMQ.get_sndhwm(s1)::Integer == 1000
end
@assert ZMQ.get_linger(s1)::Integer == 1
@assert ZMQ.ismore(s1) == false 

s2=ZMQSocket(ctx2, ZMQ_REQ)
@assert ZMQ.get_type(s1) == ZMQ_REP 
@assert ZMQ.get_type(s2) == ZMQ_REQ 

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

ZMQ.send(s2, ZMQMessage("test request"))
@assert (bytestring(ZMQ.recv(s1)) == "test request")
ZMQ.send(s1, ZMQMessage("test response"))
@assert (bytestring(ZMQ.recv(s2)) == "test response")

ZMQ.send(s2, ZMQMessage("another test request"))
msg = ZMQ.recv(s1)
o=convert(IOStream, msg)
seek(o, 0)
@assert (takebuf_string(o)=="another test request")

ZMQ.close(s1)
ZMQ.close(s2)
ZMQ.close(ctx2)






