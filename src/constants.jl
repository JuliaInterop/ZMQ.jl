
## Constants

# Context options
const IO_THREADS = 1
const MAX_SOCKETS = 2
const IPV6 = 42

"[PAIR](https://zeromq.org/socket-api/#pair-socket) socket."
const PAIR = 0
"[PUB](https://zeromq.org/socket-api/#pub-socket) socket."
const PUB = 1
"[SUB](https://zeromq.org/socket-api/#sub-socket) socket."
const SUB = 2
"[REQ](https://zeromq.org/socket-api/#req-socket) socket."
const REQ = 3
"[REP](https://zeromq.org/socket-api/#rep-socket) socket."
const REP = 4
"[DEALER](https://zeromq.org/socket-api/#dealer-socket) socket."
const DEALER = 5
"[ROUTER](https://zeromq.org/socket-api/#router-socket) socket."
const ROUTER = 6
"[PULL](https://zeromq.org/socket-api/#pull-socket) socket."
const PULL = 7
"[PUSH](https://zeromq.org/socket-api/#push-socket) socket."
const PUSH = 8
"[XPUB](https://zeromq.org/socket-api/#xpub-socket) socket."
const XPUB = 9
"[XSUB](https://zeromq.org/socket-api/#xsub-socket) socket."
const XSUB = 10
"[XREQ](https://zeromq.org/socket-api/#dealer-socket) socket."
const XREQ = DEALER
"[XREP](https://zeromq.org/socket-api/#router-socket) socket."
const XREP = ROUTER
"[UPSTREAM](https://zeromq.org/socket-api/#pull-socket) socket."
const UPSTREAM = PULL
"[DOWNSTREAM](https://zeromq.org/socket-api/#push-socket) socket."
const DOWNSTREAM = PUSH

#Message options
const MORE = 1
const SNDMORE = true

#IO Multiplexing
const POLLIN = 1
const POLLOUT = 2
const POLLERR = 4

#Built in devices
const STREAMER = 1
const FORWARDER = 2
const QUEUE = 3


#Send/Recv Options
const ZMQ_DONTWAIT = 1
const ZMQ_SNDMORE = 2
