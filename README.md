# A Julia interface to ZeroMQ

**ZMQ.jl** is a [Julia] (http://julialang.org) interface to [ZeroMQ, The Intelligent Transport Layer] (http://zeromq.org). 

## Installation
```julia
load("pkg")
Pkg.init() #If not run earlier

Pkg.add("ZMQ")
```

Install the ZeroMQ libraries for your OS using your favourite package manager for your OS. 

## Usage

```julia
require("ZMQ")
using ZMQ

ctx=ZMQContext(1)
s1=ZMQSocket(ctx, ZMQ_REP)
s2=ZMQSocket(ctx, ZMQ_REQ)

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

ZMQ.send(s2, ZMQMessage("test request"))
msg = ZMQ.recv(s1)
out=convert(IOStream, msg)
seek(out,0)
#read out::MemIO as usual, eg. read(out,...) or takebuf_string(out)
#or, conveniently, use ASCIIString[msg] to retrieve a string

ZMQ.send(s1, ZMQMessage("test response"))
ZMQ.close(s1)
ZMQ.close(s2)
ZMQ.close(ctx)

```

## RPC

This package includes an RPC mechanism to remotely execute julia functions, possibly from different programming languages. The on-the-wire protocol used for passing messages is the standard Julia serialisation format built into the standard library. 

As the functionality matures, this may be split into a separate package. 

```julia
require("ZMQ/src/RPCJuliaSer")
using RPCJuliaSer
run_server() #using port 5555 by default
```

In a separate Julia session
```jlcon
julia> require("ZMQ/src/RPCJuliaSer")

julia> using RPCJuliaSer

julia> ctx,req=launch_client()
(ZMQContext(Ptr{Void} @0x0000000103b7a600),ZMQSocket(Ptr{Void} @0x0000000103b6e890))

julia> zmqparse(req, "2+2")
4
```
