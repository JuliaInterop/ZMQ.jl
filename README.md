# A Julia interface to ZeroMQ
[![Build Status](https://api.travis-ci.org/JuliaLang/ZMQ.jl.svg)](https://travis-ci.org/JuliaLang/ZMQ.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/laybx903pd12j2ik/branch/master?svg=true)](https://ci.appveyor.com/project/tkelman/zmq-jl/branch/master)

**ZMQ.jl** is a [Julia] (http://julialang.org) interface to [ZeroMQ, The Intelligent Transport Layer] (http://zeromq.org). 

ZMQ version 3 or later is required; ZMQ version 2 is not supported.

## Installation
```julia
Pkg.add("ZMQ")
```

Install the ZeroMQ libraries for your OS using your favourite package manager. 

## Usage

```julia
using ZMQ

ctx=Context()
s1=Socket(ctx, REP)
s2=Socket(ctx, REQ)

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

ZMQ.send(s2, Message("test request"))
msg = ZMQ.recv(s1)
out=convert(IOStream, msg)
seek(out,0)
#read out::MemIO as usual, eg. read(out,...) or takebuf_string(out)
#or, conveniently, use unsafe_string(msg) to retrieve a string

ZMQ.send(s1, Message("test response"))
ZMQ.close(s1)
ZMQ.close(s2)
ZMQ.close(ctx)

```

## Troubleshooting

If you are using Windows and get an error `Provider PackageManager failed to satisfy dependency zmq`, you may need to restart Julia and run `Pkg.build("ZMQ")` again. See [issue #69](https://github.com/JuliaLang/ZMQ.jl/issues/69) for more details.
