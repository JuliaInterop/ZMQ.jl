```@meta
CurrentModule = ZMQ
```

# Reference

```@docs
lib_version
TimeoutError
```

## Sockets

The ZMQ Socket type:

```@docs
Socket
Socket(::Context, ::Integer)
Socket(::Integer)
Socket(::Function)
isopen
close
```

[`Socket`](@ref) implements the
[`Sockets`](https://docs.julialang.org/en/v1/stdlib/Sockets/) interface:
```@docs
bind
connect
recv
recv_multipart
send
send_multipart
```

ZMQ socket types (note: some of these are aliases; e.g. `XREQ = DEALER`):
```@docs
PAIR
PUB
SUB
REQ
REP
DEALER
ROUTER
PULL
PUSH
XPUB
XSUB
XREQ
XREP
UPSTREAM
DOWNSTREAM
```

## Messages

```@docs
Message
Message()
Message(::Integer)
Message(::Any)
Message(::String)
Message(::SubString{String})
Message(::DenseVector)
Message(::IOBuffer)
isfreed(::Message)
```

## Context

```@docs
ZMQ.context
```
