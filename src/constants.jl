
## Constants

# Context options
const IO_THREADS = 1
const MAX_SOCKETS = 2
const IPV6 = 42

#Socket Types
const PAIR = 0
const PUB = 1
const SUB = 2
const REQ = 3
const REP = 4
const DEALER = 5
const ROUTER = 6
const PULL = 7
const PUSH = 8
const XPUB = 9
const XSUB = 10
const XREQ = DEALER
const XREP = ROUTER
const UPSTREAM = PULL
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