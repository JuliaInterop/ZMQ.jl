# A Julia interface to ZeroMQ
[![Build Status](https://api.travis-ci.org/JuliaInterop/ZMQ.jl.svg)](https://travis-ci.org/JuliaInterop/ZMQ.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/u1d6dpovaptdqalh?svg=true)](https://ci.appveyor.com/project/StevenGJohnson/zmq-jl)

**ZMQ.jl** is a [Julia](http://julialang.org) interface to [ZeroMQ, The Intelligent Transport Layer](http://zeromq.org).

## Installation
```julia
Pkg.add("ZMQ")
```

(This installs its own copy of the ZMQ libraries from the [ZMQBuilder](https://github.com/JuliaInterop/ZMQBuilder) repository.)

## Usage

```julia
using ZMQ

s1=Socket(REP)
s2=Socket(REQ)

ZMQ.bind(s1, "tcp://*:5555")
ZMQ.connect(s2, "tcp://localhost:5555")

ZMQ.send(s2, Message("test request"))
msg = ZMQ.recv(s1)
out=convert(IOStream, msg)
seek(out,0)
#read out::MemIO as usual, eg. read(out,...) or takebuf_string(out)
#or, conveniently, use unsafe_string(msg) to retrieve a string

ZMQ.send(s1, Message("test response"))
close(s1)
close(s2)

```

## Troubleshooting

If you are using Windows and get an error `Provider PackageManager failed to satisfy dependency zmq`, you may need to restart Julia and run `Pkg.build("ZMQ")` again. See [issue #69](https://github.com/JuliaLang/ZMQ.jl/issues/69) for more details.
