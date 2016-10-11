# Support for ZeroMQ, a network and interprocess communication library

__precompile__(true)

module ZMQ
using Compat
import Compat: String, unsafe_string
import Base.unsafe_convert
using Base.Libdl, Base.Libc
using Base.Libdl: dlopen_e
using Base.Libc: EAGAIN

if VERSION >= v"0.5.0-dev+1229"
    import Base.Filesystem: UV_READABLE, uv_pollcb
else
    import Base: UV_READABLE
    if isdefined(Base, :uv_pollcb)
        import Base: uv_pollcb
    end
end

const depfile = joinpath(dirname(@__FILE__),"..","deps","deps.jl")
if isfile(depfile)
    include(depfile)
else
    error("ZMQ not properly installed. Please run Pkg.build(\"ZMQ\")")
end

import Base:
    convert, get, bytestring,
    length, size, stride, similar, getindex, setindex!,
    fd, wait, notify, close, connect,
    bind, send, recv

export
    #Types
    StateError,Context,Socket,Message,
    #functions
    set, subscribe, unsubscribe,
    #Constants
    IO_THREADS,MAX_SOCKETS,PAIR,PUB,SUB,REQ,REP,ROUTER,DEALER,PULL,PUSH,XPUB,XSUB,XREQ,XREP,UPSTREAM,DOWNSTREAM,MORE,POLLIN,POLLOUT,POLLERR,STREAMER,FORWARDER,QUEUE,SNDMORE
const SNDMORE = true

# A server will report most errors to the client over a Socket, but
# errors in ZMQ state can't be reported because the socket may be
# corrupted. Therefore, we need an exception type for errors that
# should be reported locally.
type StateError <: Exception
    msg::AbstractString
end
show(io, thiserr::StateError) = print(io, "ZMQ: ", thiserr.msg)

# Basic functions
zmq_errno() = ccall((:zmq_errno, zmq), Cint, ())
function jl_zmq_error_str()
    errno = zmq_errno()
    c_strerror = ccall ((:zmq_strerror, zmq), Ptr{UInt8}, (Cint,), errno)
    if c_strerror != C_NULL
        strerror = unsafe_string(c_strerror)
        return strerror
    else
        return "Unknown error"
    end
end

if VERSION >= v"0.5-" && isdefined(Base, :Filesystem)
    if is_windows()
        using Base.Libc: WindowsRawSocket
    end
    const _FDWatcher = Base.Filesystem._FDWatcher
    const _have_good_fdwatcher = true
elseif VERSION >= v"0.4-" && isdefined(Base, :_FDWatcher)
    if is_windows()
        using Base.Libc: WindowsRawSocket
    end
    const _FDWatcher = Base._FDWatcher
    const _have_good_fdwatcher = true
else
    if is_windows()
        using Base: WindowsRawSocket
    end
    const _FDWatcher = Base.FDWatcher
    const _have_good_fdwatcher = false
end

## Sockets ##
type Socket
    data::Ptr{Void}
    pollfd::_FDWatcher

    # ctx should be ::Context, but forward type references are not allowed
    function Socket(ctx, typ::Integer)
        p = ccall((:zmq_socket, zmq), Ptr{Void}, (Ptr{Void}, Cint), ctx.data, typ)
        if p == C_NULL
            throw(StateError(jl_zmq_error_str()))
        end
        socket = new(p)
        if _have_good_fdwatcher
            socket.pollfd = _FDWatcher(fd(socket), #=readable=#true, #=writable=#false)
        else
            socket.pollfd = _FDWatcher(fd(socket))
        end
        finalizer(socket, close)
        push!(ctx.sockets, socket)
        return socket
    end
end

function close(socket::Socket)
    if socket.data != C_NULL
        data = socket.data
        socket.data = C_NULL
        if _have_good_fdwatcher
            close(socket.pollfd, #=readable=#true, #=writable=#false)
        else
            notify(socket.pollfd.notify)
            Base.stop_watching(socket.pollfd)
        end
        rc = ccall((:zmq_close, zmq), Cint,  (Ptr{Void},), data)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
    end
end


## Contexts ##
# Provide the same constructor API for version 2 and version 3, even
# though the underlying functions are changing
type Context
    data::Ptr{Void}

    # need to keep a list of sockets for this Context in order to
    # close them before finalizing (otherwise zmq_term will hang)
    sockets::Vector{Socket}

    function Context()
        p = ccall((:zmq_ctx_new, zmq), Ptr{Void},  ())
        if p == C_NULL
            throw(StateError(jl_zmq_error_str()))
        end
        zctx = new(p, Array(Socket,0))
        finalizer(zctx, close)
        return zctx
    end
end

@deprecate Context(n::Integer) Context()

function close(ctx::Context)
    if ctx.data != C_NULL # don't close twice!
        data = ctx.data
        ctx.data = C_NULL
        for s in ctx.sockets
            close(s)
        end
        rc = ccall((:zmq_ctx_destroy, zmq), Cint,  (Ptr{Void},), data)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
    end
end
term(ctx::Context) = close(ctx)

function get(ctx::Context, option::Integer)
    val = ccall((:zmq_ctx_get, zmq), Cint, (Ptr{Void}, Cint), ctx.data, option)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    return val
end

function set(ctx::Context, option::Integer, value::Integer)
    rc = ccall((:zmq_ctx_set, zmq), Cint, (Ptr{Void}, Cint, Cint), ctx.data, option, value)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

# Getting and setting socket options
# Socket options of integer type
const u64p = zeros(UInt64, 1)
const i64p = zeros(Int64, 1)
const ip = zeros(Cint, 1)
const u32p = zeros(UInt32, 1)
const sz = zeros(UInt, 1)
const pp = fill(C_NULL, 1)

for (fset, fget, k, p) in [
    (:set_affinity,                :get_affinity,                 4, u64p)
    (:set_type,                    :get_type,                    16,   ip)
    (:set_linger,                  :get_linger,                  17,   ip)
    (:set_reconnect_ivl,           :get_reconnect_ivl,           18,   ip)
    (:set_backlog,                 :get_backlog,                 19,   ip)
    (:set_reconnect_ivl_max,       :get_reconnect_ivl_max,       21,   ip)
    (:set_rate,                    :get_rate,                     8,   ip)
    (:set_recovery_ivl,            :get_recovery_ivl,             9,   ip)
    (:set_sndbuf,                  :get_sndbuf,                  11,   ip)
    (:set_rcvbuf,                  :get_rcvbuf,                  12,   ip)
    (nothing,                      :_zmq_getsockopt_rcvmore,     13,   ip)
    (nothing,                      :get_events,                  15,   ip)
    (:set_maxmsgsize,              :get_maxmsgsize,              22,   ip)
    (:set_sndhwm,                  :get_sndhwm,                  23,   ip)
    (:set_rcvhwm,                  :get_rcvhwm,                  24,   ip)
    (:set_multicast_hops,          :get_multicast_hops,          25,   ip)
    (:set_ipv4only,                :get_ipv4only,                31,   ip)
    (:set_tcp_keepalive,           :get_tcp_keepalive,           34,   ip)
    (:set_tcp_keepalive_idle,      :get_tcp_keepalive_idle,      35,   ip)
    (:set_tcp_keepalive_cnt,       :get_tcp_keepalive_cnt,       36,   ip)
    (:set_tcp_keepalive_intvl,     :get_tcp_keepalive_intvl,     37,   ip)
    (:set_rcvtimeo,                :get_rcvtimeo,                27,   ip)
    (:set_sndtimeo,                :get_sndtimeo,                28,   ip)
    (nothing,                      :get_fd,                      14, is_windows() ? pp : ip)
    ]
    if fset != nothing
        @eval function ($fset)(socket::Socket, option_val::Integer)
            ($p)[1] = option_val
            rc = ccall((:zmq_setsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{Void}, UInt),
                       socket.data, $k, $p, sizeof(eltype($p)))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
    end
    if fget != nothing
        @eval function ($fget)(socket::Socket)
            ($sz)[1] = sizeof(eltype($p))
            rc = ccall((:zmq_getsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{Void}, Ptr{UInt}),
                       socket.data, $k, $p, $sz)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return @compat Int(($p)[1])
        end
    end
end

# For some functions, the publicly-visible versions should require &
# return boolean:
get_rcvmore(socket::Socket) = @compat Bool(_zmq_getsockopt_rcvmore(socket))
# And a convenience function
ismore(socket::Socket) = get_rcvmore(socket)

# subscribe/unsubscribe options take an arbitrary byte array
for (f,k) in ((:subscribe,6), (:unsubscribe,7))
    f_ = @compat Symbol(string(f, "_"))
    @eval begin
        function $f_{T}(socket::Socket, filter::Ptr{T}, len::Integer)
            rc = ccall((:zmq_setsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{T}, UInt),
                       socket.data, $k, filter, len)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
        @compat $f(socket::Socket, filter::Union{Array,AbstractString}) =
            $f_(socket, pointer(filter), sizeof(filter))
        $f(socket::Socket) = $f_(socket, C_NULL, 0)
    end
end

# Raw FD access
if is_unix()
    fd(socket::Socket) = RawFD(get_fd(socket))
end
if is_windows()
    fd(socket::Socket) = WindowsRawSocket(convert(Ptr{Void}, get_fd(socket)))
end

if _have_good_fdwatcher
    wait(socket::Socket) = wait(socket.pollfd, readable=true, writable=false)
    notify(socket::Socket) = uv_pollcb(socket.pollfd.handle, Int32(0),
                                       Int32(UV_READABLE))
else
    wait(socket::Socket) = Base._wait(socket.pollfd, #=readable=#true, #=writable=#false)
    notify(socket::Socket) = Base._uv_hook_pollcb(socket.pollfd, int32(0),
                                                  int32(UV_READABLE))
end

# Socket options of string type
const u8ap = zeros(UInt8, 255)
for (fset, fget, k) in [
    (:set_identity,                :get_identity,                5)
    (:set_subscribe,               nothing,                      6)
    (:set_unsubscribe,             nothing,                      7)
    (nothing,                      :get_last_endpoint,          32)
    (:set_tcp_accept_filter,       nothing,                     38)
    ]
    if fset != nothing
        @eval function ($fset)(socket::Socket, option_val::String)
            if length(option_val) > 255
                throw(StateError("option value too large"))
            end
            rc = ccall((:zmq_setsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{UInt8}, UInt),
                       socket.data, $k, option_val, length(option_val))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
    end
    if fget != nothing
        @eval function ($fget)(socket::Socket)
            ($sz)[1] = length($u8ap)
            rc = ccall((:zmq_getsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{UInt8}, Ptr{UInt}),
                       socket.data, $k, $u8ap, $sz)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return unsafe_string(unsafe_convert(Ptr{UInt8}, $u8ap), @compat Int(($sz)[1]))
        end
    end
end

function bind(socket::Socket, endpoint::AbstractString)
    rc = ccall((:zmq_bind, zmq), Cint, (Ptr{Void}, Ptr{UInt8}), socket.data, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

function connect(socket::Socket, endpoint::AbstractString)
    rc=ccall((:zmq_connect, zmq), Cint, (Ptr{Void}, Ptr{UInt8}), socket.data, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

# in order to support zero-copy messages that share data with Julia
# arrays, we need to hold a reference to the Julia object in a dictionary
# until zeromq is done with the data, to prevent it from being garbage
# collected.  The gc_protect dictionary is keyed by a uv_async_t* pointer,
# used in uv_async_send to tell Julia to when zeromq is done with the data.
const gc_protect = Dict{Ptr{Void},Any}()
# 0.2 compatibility
gc_protect_cb(work, status) = gc_protect_cb(work)
close_handle(work) = Base.close(work)
gc_protect_cb(work) = (pop!(gc_protect, work.handle, nothing); close_handle(work))

function gc_protect_handle(obj::Any)
    work = Compat.AsyncCondition(gc_protect_cb)
    gc_protect[work.handle] = (work,obj)
    work.handle
end

# Thread-safe zeromq callback when data is freed, passed to zmq_msg_init_data.
# The hint parameter will be a uv_async_t* pointer.
function gc_free_fn(data::Ptr{Void}, hint::Ptr{Void})
    ccall(:uv_async_send,Cint,(Ptr{Void},),hint)
end

## Messages ##
bitstype 64 * 8 MsgPadding

type Message <: AbstractArray{UInt8,1}
    # Matching the declaration in the header: char _[64];
    w_padding::MsgPadding
    handle::Ptr{Void} # index into gc_protect, if any

    # Create an empty message (for receive)
    function Message()
        zmsg = new()
        zmsg.handle = C_NULL
        rc = ccall((:zmq_msg_init, zmq), Cint, (Ptr{Message},), &zmsg)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(zmsg, close)
        return zmsg
    end
    # Create a message with a given buffer size (for send)
    function Message(len::Integer)
        zmsg = new()
        zmsg.handle = C_NULL
        rc = ccall((:zmq_msg_init_size, zmq), Cint, (Ptr{Message}, Csize_t), &zmsg, len)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(zmsg, close)
        return zmsg
    end

    # low-level function to create a message (for send) with an existing
    # data buffer, without making a copy.  The origin parameter should
    # be the Julia object that is the origin of the data, so that
    # we can hold a reference to it until zeromq is done with the buffer.
    function Message{T}(origin::Any, m::Ptr{T}, len::Integer)
        zmsg = new()
        zmsg.handle = gc_protect_handle(origin)
        rc = ccall((:zmq_msg_init_data, zmq), Cint, (Ptr{Message}, Ptr{T}, Csize_t, Ptr{Void}, Ptr{Void}), &zmsg, m, len, gc_free_fn_c::Ptr{Void}, zmsg.handle)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(zmsg, close)
        return zmsg
    end

    # Create a message with a given AbstractString or Array as a buffer (for send)
    # (note: now "owns" the buffer ... the Array must not be resized,
    #        or even written to after the message is sent!)
    Message(m::String) = Message(m, unsafe_convert(Ptr{UInt8}, pointer(m)), sizeof(m))
    Message{T<:String}(p::SubString{T}) =
        Message(p, pointer(p.string.data)+p.offset, sizeof(p))
    Message(a::Array) = Message(a, pointer(a), sizeof(a))
    function Message(io::IOBuffer)
        if !io.readable || !io.seekable
            error("byte read failed")
        end
        Message(io.data)
    end
end

# check whether zeromq has called our free-function, i.e. whether
# we are save to reclaim ownership of any buffer object
isfreed(m::Message) = haskey(gc_protect, m.handle)

# AbstractArray behaviors:
similar(a::Message, T, dims::Dims) = Array(T, dims) # ?
length(zmsg::Message) = @compat Int(ccall((:zmq_msg_size, zmq), Csize_t, (Ptr{Message},), &zmsg))
size(zmsg::Message) = (length(zmsg),)
unsafe_convert(::Type{Ptr{UInt8}}, zmsg::Message) = ccall((:zmq_msg_data, zmq), Ptr{UInt8}, (Ptr{Message},), &zmsg)
function getindex(a::Message, i::Integer)
    if i < 1 || i > length(a)
        throw(BoundsError())
    end
    unsafe_load(pointer(a), i)
end
function setindex!(a::Message, v, i::Integer)
    if i < 1 || i > length(a)
        throw(BoundsError())
    end
    unsafe_store(pointer(a), v, i)
end

# Convert message to string (copies data)
unsafe_string(zmsg::Message) = Compat.unsafe_string(pointer(zmsg), length(zmsg))
if VERSION < v"0.5-dev+4341"
    bytestring(zmsg::Message) = unsafe_string(zmsg)
else
    @deprecate bytestring(zmsg::Message) unsafe_string(zmsg::Message)
end

# Build an IOStream from a message
# Copies the data
function convert(::Type{IOStream}, zmsg::Message)
    s = IOBuffer()
    write(s, zmsg)
    return s
end
# Close a message. You should not need to call this manually (let the
# finalizer do it).
function close(zmsg::Message)
    rc = ccall((:zmq_msg_close, zmq), Cint, (Ptr{Message},), &zmsg)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

function get(zmsg::Message, property::Integer)
    val = ccall((:zmq_msg_get, zmq), Cint, (Ptr{Message}, Cint), &zmsg, property)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    val
end
function set(zmsg::Message, property::Integer, value::Integer)
    rc = ccall((:zmq_msg_set, zmq), Cint, (Ptr{Message}, Cint, Cint), &zmsg, property, value)
    if rc < 0
        throw(StateError(jl_zmq_error_str()))
    end
end

## Send/receive messages
#
# Julia defines two types of ZMQ messages: "raw" and "serialized". A "raw"
# message is just a plain ZeroMQ message, used for sending a sequence
# of bytes. You send these with the following:
#   send(socket, zmsg)
#   zmsg = recv(socket)

#Send/Recv Options
const ZMQ_DONTWAIT = 1
const ZMQ_SNDMORE = 2

function send(socket::Socket, zmsg::Message, SNDMORE::Bool=false)
    while true
        rc = ccall((:zmq_msg_send, zmq), Cint, (Ptr{Message}, Ptr{Void}, Cint),
                    &zmsg, socket.data, (ZMQ_SNDMORE*SNDMORE) | ZMQ_DONTWAIT)
        if rc == -1
            zmq_errno() == EAGAIN || throw(StateError(jl_zmq_error_str()))
            while (get_events(socket) & POLLOUT) == 0
                wait(socket)
            end
        else
            get_events(socket) != 0 && notify(socket)
            break
        end
    end
end

# strings are immutable, so we can send them zero-copy by default
send(socket::Socket, msg::AbstractString, SNDMORE::Bool=false) = send(socket, Message(msg), SNDMORE)

# Make a copy of arrays before sending, by default, since it is too
# dangerous to require that the array not change until ZMQ is done with it.
# For zero-copy array messages, construct a Message explicitly.
send(socket::Socket, msg::AbstractArray, SNDMORE::Bool=false) = send(socket, Message(copy(msg)), SNDMORE)

function send(f::Function, socket::Socket, SNDMORE::Bool=false)
    io = IOBuffer()
    f(io)
    send(socket, Message(io), SNDMORE)
end

function recv(socket::Socket)
    zmsg = Message()
    rc = -1
    while true
        rc = ccall((:zmq_msg_recv, zmq), Cint, (Ptr{Message}, Ptr{Void}, Cint),
                    &zmsg, socket.data, ZMQ_DONTWAIT)
        if rc == -1
            zmq_errno() == EAGAIN || throw(StateError(jl_zmq_error_str()))
            while (get_events(socket) & POLLIN) == 0
                wait(socket)
            end
        else
            get_events(socket) != 0 && notify(socket)
            break
        end
    end
    return zmsg
end

## Constants

# Context options
const IO_THREADS = 1
const MAX_SOCKETS = 2

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

#IO Multiplexing
const POLLIN = 1
const POLLOUT = 2
const POLLERR = 4

#Built in devices
const STREAMER = 1
const FORWARDER = 2
const QUEUE = 3

function __init__()
    major = Array(Cint,1)
    minor = Array(Cint,1)
    patch = Array(Cint,1)
    ccall((:zmq_version, zmq), Void, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major, minor, patch)
    global const version = VersionNumber(major[1], minor[1], patch[1])
    if version < v"3"
        error("ZMQ version $version < 3 is not supported")
    end
    global const gc_free_fn_c = cfunction(gc_free_fn, Cint, (Ptr{Void}, Ptr{Void}))
end

end
