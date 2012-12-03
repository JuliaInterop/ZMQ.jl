
load ("ZMQ")
using Base
using ZMQ


@assert length(ZMQ.version()) == 3

ctx=ZMQContext(1)

@assert typeof(ctx) == ZMQContext

try 
	ZMQContext(-1)
	@assert false
catch ex
	@assert typeof(ex) == ZMQStateError
end 

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
ZMQ.set_hwm(s1, 1000)
ZMQ.set_linger(s1, 1)
ZMQ.set_identity(s1, "abcd")


@assert ZMQ.get_identity(s1)::String == "abcd"
@assert ZMQ.get_hwm(s1)::Integer == 1000
@assert ZMQ.get_linger(s1)::Integer == 1
@assert ZMQ.get_rcvmore(s1) == false 

s2=ZMQSocket(ctx2, ZMQ_REQ)
@assert ZMQ.get_type(s1) == ZMQ_REP 
@assert ZMQ.get_type(s2) == ZMQ_REQ 

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

ZMQ.send(s2, ZMQMessage("test request"))
@assert (ASCIIString[ZMQ.recv(s1)] == "test request")
ZMQ.send(s1, ZMQMessage("test response"))
@assert (ASCIIString[ZMQ.recv(s2)] == "test response")

ZMQ.send(s2, ZMQMessage("another test request"))
msg = ZMQ.recv(s1)
o=convert(IOStream, msg)
seek(o, 0)
@assert (takebuf_string(o)=="another test request")

ZMQ.close(s1)
ZMQ.close(s2)
ZMQ.close(ctx2)






