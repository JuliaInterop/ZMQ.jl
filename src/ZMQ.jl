# Support for ZeroMQ, a network and interprocess communication library

module ZMQ

using Base.Libc: EAGAIN
using FileWatching: UV_READABLE, uv_pollcb, FDWatcher, FDEvent, poll_fd
using Printf: @sprintf
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

@static if Sys.iswindows()
    @static if Sys.WORD_SIZE == 32
        include("../lib/i686-w64-mingw32.jl")
    else
        include("../lib/x86_64-w64-mingw32.jl")
    end
else
    include("../lib/x86_64-linux-gnu.jl")
end

include("constants.jl")
include("optutil.jl")
include("error.jl")
include("context.jl")
include("socket.jl")
include("sockopts.jl")
include("message.jl")
include("msg_bindings.jl")
include("comm.jl")
include("poller.jl")

"""
    lib_version()

Get the libzmq version number.
"""
function lib_version()
    major = Ref{Cint}()
    minor = Ref{Cint}()
    patch = Ref{Cint}()
    lib.zmq_version(major, minor, patch)
    return VersionNumber(major[], minor[], patch[])
end

const version = lib_version()

function __init__()
    if lib_version() < v"3"
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

    # Note that ZMQ < 4.3.5 can only bind to IP address or network interface, not hostname
    ZMQ.bind(s1, "tcp://127.0.0.1:*")
    # Strip the trailing null-terminator
    last_endpoint = s1.last_endpoint[1:end - 1]
    # Parse the port from the endpoint
    port = parse(Int, split(last_endpoint, ":")[end])
    ZMQ.connect(s2, "tcp://127.0.0.1:$(port)")

    msg = Message("test request")

    ZMQ.send(s2, msg)
    unsafe_string(ZMQ.recv(s1))
    ZMQ.send(s1, Message("test response"))

    p = Poller([s2])
    wait(p)
    unsafe_string(ZMQ.recv(s2))

    close(p)
    ZMQ.close(s1)
    ZMQ.close(s2)

    # Precompile methods that are likely to be called when an exception is
    # thrown.
    repr(TimeoutError(repr(s1), 0.5))
    repr(StateError("foo"))

    # Using the library like this workload will initialize ZMQ._context, which
    # contains a pointer. This doesn't seem to play well with serialization on
    # Julia 1.6 with PackageCompiler so we explicitly close it to reset the
    # pointer.
    # See: https://github.com/JuliaLang/julia/issues/46214
    close(ZMQ._context)
end

end
