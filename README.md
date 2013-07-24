# A Julia interface to ZeroMQ
[![Build Status](https://travis-ci.org/aviks/ZMQ.jl.png)](https://travis-ci.org/aviks/ZMQ.jl)

**ZMQ.jl** is a [Julia] (http://julialang.org) interface to [ZeroMQ, The Intelligent Transport Layer] (http://zeromq.org). 

This codebase has been tested to work with ZeroMQ version 2.2.0 and 3.2.2. The unit tests within this package run successfully on both versions of the library. 


## Installation
```julia
Pkg.add("ZMQ")
```

Install the ZeroMQ libraries for your OS using your favourite package manager. 

## Usage

```julia
using ZMQ

ctx=Context(1)
s1=Socket(ctx, REP)
s2=Socket(ctx, REQ)

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

ZMQ.send(s2, Message("test request"))
msg = ZMQ.recv(s1)
out=convert(IOStream, msg)
seek(out,0)
#read out::MemIO as usual, eg. read(out,...) or takebuf_string(out)
#or, conveniently, use ASCIIString[msg] to retrieve a string

ZMQ.send(s1, Message("test response"))
ZMQ.close(s1)
ZMQ.close(s2)
ZMQ.close(ctx)

```
