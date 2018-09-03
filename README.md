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

bind(s1, "tcp://*:5555")
connect(s2, "tcp://localhost:5555")

send(s2, "test request")
msg = recv(s1, String)
send(s1, "test response")
close(s1)
close(s2)
```

The `send(socket, x)` and `recv(socket, SomeType)` functions make an extra copy of the data when converting
between ZMQ and Julia.   Alternatively, for large data sets (e.g. very large arrays or long strings), it can
be preferable to share data, with `send(socket, Message(x))` and `msg = recv(Message)`, where the `msg::Message`
object acts like an array of bytes; this involves some overhead so it may not be optimal for short messages.

(Help in writing more detailed documentation would be welcome!)

## Troubleshooting

If you are using Windows and get an error `Provider PackageManager failed to satisfy dependency zmq`, you may need to restart Julia and run `Pkg.build("ZMQ")` again. See [issue #69](https://github.com/JuliaLang/ZMQ.jl/issues/69) for more details.
