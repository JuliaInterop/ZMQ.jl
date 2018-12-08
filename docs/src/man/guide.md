# Guide

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

