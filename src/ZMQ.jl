# Support for ZeroMQ, a network and interprocess communication library

__precompile__(true)

module ZMQ

using Compat
import Base: unsafe_convert, unsafe_string
using Compat.Libdl, Compat.Libc
using Base.Libc: EAGAIN
@static if VERSION < v"0.7.0-DEV.2359"
    import Base.Filesystem: UV_READABLE, uv_pollcb, _FDWatcher
else
    import FileWatching: UV_READABLE, uv_pollcb, _FDWatcher
end

const depsjl_path = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if !isfile(depsjl_path)
    error("Blosc not installed properly, run Pkg.build(\"ZMQ\"), restart Julia and try again")
end
include(depsjl_path)

import Base:
    convert, get,
    length, size, stride, similar, getindex, setindex!,
    fd, wait, notify, close

import Compat.Sockets: connect, bind, send, recv

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
include("error.jl")
include("socket.jl")
include("context.jl")
include("message.jl")

const gc_free_fn_c = Ref{Ptr{Cvoid}}()

function __init__()
    check_deps()
    major = Ref{Cint}()
    minor = Ref{Cint}()
    patch = Ref{Cint}()
    ccall((:zmq_version, libzmq), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major, minor, patch)
    global version = VersionNumber(major[], minor[], patch[])
    if version < v"3"
        error("ZMQ version $version < 3 is not supported")
    end
    gc_free_fn_c[] = @cfunction(gc_free_fn, Cint, (Ptr{Cvoid}, Ptr{Cvoid}))
end

end
