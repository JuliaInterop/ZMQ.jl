# Support for ZeroMQ, a network and interprocess communication library

module ZMQ
import ZeroMQ_jll: libzmq

using Base.Libc: EAGAIN
using FileWatching: UV_READABLE, uv_pollcb, FDWatcher
import Sockets
using Sockets: connect, bind, send, recv
import Base.GC: @preserve

export
    #Types
    StateError,Context,Socket,Message,
    #functions
    set, subscribe, unsubscribe,
    #Constants
    IO_THREADS,MAX_SOCKETS,PAIR,PUB,SUB,REQ,REP,ROUTER,DEALER,PULL,PUSH,XPUB,XSUB,XREQ,XREP,UPSTREAM,DOWNSTREAM,MORE,POLLIN,POLLOUT,POLLERR,STREAMER,FORWARDER,QUEUE,SNDMORE,
    #Sockets
    connect, bind, send, recv


include("constants.jl")
include("optutil.jl")
include("error.jl")
include("context.jl")
include("socket.jl")
include("sockopts.jl")
include("message.jl")
include("comm.jl")

function __init__()
    major = Ref{Cint}()
    minor = Ref{Cint}()
    patch = Ref{Cint}()
    ccall((:zmq_version, libzmq), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major, minor, patch)
    global version = VersionNumber(major[], minor[], patch[])
    if version < v"3"
        error("ZMQ version $version < 3 is not supported")
    end
    atexit() do
        close(_context)
    end
end

import PrecompileTools: @compile_workload
@compile_workload begin
    __init__()
    # The ZMQ scoping below isn't necessary, but it makes it easier to copy/paste
    # the workload to test impact.
    s=Socket(PUB)
    ZMQ.close(s)

    s1=Socket(REP)
    s1.sndhwm = 1000
    s1.linger = 1
    s1.routing_id = "abcd"

    s2=Socket(REQ)

    # zmq < 4.3.5 can only bind to ip address or network interface, not hostname
    localhost_ip = Sockets.getaddrinfo("localhost", Sockets.IPv4)
    ZMQ.bind(s1, "tcp://$(localhost_ip):*")
    # Strip the trailing null-terminator
    last_endpoint = s1.last_endpoint[1:end - 1]
    # Parse the port from the endpoint
    port = parse(Int, split(last_endpoint, ":")[end])
    ZMQ.connect(s2, "tcp://$(localhost_ip):$(port)")

    msg = Message("test request")

    ZMQ.send(s2, msg)
    unsafe_string(ZMQ.recv(s1))
    ZMQ.send(s1, Message("test response"))
    unsafe_string(ZMQ.recv(s2))
    ZMQ.close(s1)
    ZMQ.close(s2)
end

end
