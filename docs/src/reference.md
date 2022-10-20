# Reference

## Sockets

The ZMQ Socket type:

```@docs
Socket
isopen
close
```

[`Socket`](@ref) implements the
[`Sockets`](https://docs.julialang.org/en/v1/stdlib/Sockets/) interface:
```@docs
bind
connect
recv
send
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
```

## Context

```@docs
ZMQ.context
```
