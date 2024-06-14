
## Constants

# Context options
const IO_THREADS = lib.ZMQ_IO_THREADS
const MAX_SOCKETS = lib.ZMQ_MAX_SOCKETS
const IPV6 = lib.ZMQ_IPV6

"[PAIR](https://zeromq.org/socket-api/#pair-socket) socket."
const PAIR = lib.ZMQ_PAIR
"[PUB](https://zeromq.org/socket-api/#pub-socket) socket."
const PUB = lib.ZMQ_PUB
"[SUB](https://zeromq.org/socket-api/#sub-socket) socket."
const SUB = lib.ZMQ_SUB
"[REQ](https://zeromq.org/socket-api/#req-socket) socket."
const REQ = lib.ZMQ_REQ
"[REP](https://zeromq.org/socket-api/#rep-socket) socket."
const REP = lib.ZMQ_REP
"[DEALER](https://zeromq.org/socket-api/#dealer-socket) socket."
const DEALER = lib.ZMQ_DEALER
"[ROUTER](https://zeromq.org/socket-api/#router-socket) socket."
const ROUTER = lib.ZMQ_ROUTER
"[PULL](https://zeromq.org/socket-api/#pull-socket) socket."
const PULL = lib.ZMQ_PULL
"[PUSH](https://zeromq.org/socket-api/#push-socket) socket."
const PUSH = lib.ZMQ_PUSH
"[XPUB](https://zeromq.org/socket-api/#xpub-socket) socket."
const XPUB = lib.ZMQ_XPUB
"[XSUB](https://zeromq.org/socket-api/#xsub-socket) socket."
const XSUB = lib.ZMQ_XSUB
"""
[XREQ](https://zeromq.org/socket-api/#dealer-socket) socket.

!!! compat
    This is a deprecated alias for [ZMQ.DEALER](@ref).
"""
const XREQ = DEALER

"""
[XREP](https://zeromq.org/socket-api/#router-socket) socket.

!!! compat
    This is a deprecated alias for [ZMQ.ROUTER](@ref).
"""
const XREP = ROUTER

"""
[UPSTREAM](https://zeromq.org/socket-api/#pull-socket) socket.

!!! compat
    This is a deprecated alias for [ZMQ.PULL](@ref).
"""
const UPSTREAM = PULL

"""
[DOWNSTREAM](https://zeromq.org/socket-api/#push-socket) socket.

!!! compat
    This is a deprecated alias for [ZMQ.PUSH](@ref).
"""
const DOWNSTREAM = PUSH

#Message options
const MORE = lib.ZMQ_MORE
const SNDMORE = true

#IO Multiplexing
const POLLIN = lib.ZMQ_POLLIN
const POLLOUT = lib.ZMQ_POLLOUT
const POLLERR = lib.ZMQ_POLLERR

#Built in devices
const STREAMER = lib.ZMQ_STREAMER
const FORWARDER = lib.ZMQ_FORWARDER
const QUEUE = lib.ZMQ_QUEUE


#Send/Recv Options
const ZMQ_DONTWAIT = lib.ZMQ_DONTWAIT
const ZMQ_SNDMORE = lib.ZMQ_SNDMORE
