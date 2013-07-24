# Support for ZeroMQ, a network and interprocess communication library

module ZMQ

using BinDeps
@BinDeps.load_dependencies

import Base: convert, ref, get, bytestring, length, size, stride, similar, getindex, setindex!, fd, wait

export 
    #Types
    StateError,Context,Socket,Message,
    #functions
    close, get, set, bind, connect,send,recv,convert, ref, 
    #Constants
    IO_THREADS,MAX_SOCKETS,PAIR,PUB,SUB,REQ,REP,ROUTER,DEALER,PULL,PUSH,XPUB,XPUB,XREQ,XREP,UPSTREAM,DOWNSTREAM,MORE,MORE,SNDMORE,POLLIN,POLLOUT,POLLERR,STREAMER,FORWARDER,QUEUE

# A server will report most errors to the client over a Socket, but
# errors in ZMQ state can't be reported because the socket may be
# corrupted. Therefore, we need an exception type for errors that
# should be reported locally.
type StateError <: Exception
    msg::String
end
show(io, thiserr::StateError) = print(io, "ZMQ: ", thiserr.msg)

# Basic functions
function jl_zmq_error_str()
    errno = ccall((:zmq_errno, zmq), Cint, ())
    c_strerror = ccall ((:zmq_strerror, zmq), Ptr{Uint8}, (Cint,), errno)
    if c_strerror != C_NULL
        strerror = bytestring(c_strerror)
        return strerror
    else 
        return "Unknown error"
    end
end

const version = let major = zeros(Cint, 1), minor = zeros(Cint, 1), patch = zeros(Cint, 1)
    ccall((:zmq_version, zmq), Void, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major, minor, patch)
    VersionNumber(major[1], minor[1], patch[1])
end

# define macro to enable version specific code
macro v2only(ex)
    version.major == 2 ? esc(ex) : :nothing
end
macro v3only(ex)
    version.major >= 3 ? esc(ex) : :nothing
end


## Sockets ##
type Socket
    data::Ptr{Void}

    # ctx should be ::Context, but forward type references are not allowed
    function Socket(ctx, typ::Integer)
        p = ccall((:zmq_socket, zmq), Ptr{Void},  (Ptr{Void}, Cint), ctx.data, typ)
        if p == C_NULL
            throw(StateError(jl_zmq_error_str()))
        end
        socket = new(p)
        finalizer(socket, close)
        push!(ctx.sockets, socket)
        return socket
    end
end

function close(socket::Socket)
    if socket.data != C_NULL
        rc = ccall((:zmq_close, zmq), Cint,  (Ptr{Void},), socket.data)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        socket.data = C_NULL
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

    function Context(n::Integer)
        @v2only p = ccall((:zmq_init, zmq), Ptr{Void},  (Cint,), n)
        @v3only p = ccall((:zmq_ctx_new, zmq), Ptr{Void},  ())
        if p == C_NULL
            throw(StateError(jl_zmq_error_str()))
        end
        zctx = new(p, Array(Socket,0))
        finalizer(zctx, close)
        return zctx
    end
end
Context() = Context(1)

function close(ctx::Context)
    if ctx.data != C_NULL # don't close twice!
        for s in ctx.sockets
            close(s)
        end
        @v2only rc = ccall((:zmq_term, zmq), Cint,  (Ptr{Void},), ctx.data)
        @v3only rc = ccall((:zmq_ctx_destroy, zmq), Cint,  (Ptr{Void},), ctx.data)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        ctx.data = C_NULL
    end
end
term(ctx::Context) = close(ctx)

@v3only begin
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
end # end v3only


# Getting and setting socket options
# Socket options of integer type
let u64p = zeros(Uint64, 1), i64p = zeros(Int64, 1), ip = zeros(Cint, 1), u32p = zeros(Uint32, 1), sz = zeros(Uint, 1), 
    pp = zeros(Ptr{Void},1)
opslist = {
    (:set_affinity,                :get_affinity,                 4, u64p)
    (:set_type,                    :get_type,                    16,   ip)
    (:set_linger,                  :get_linger,                  17,   ip)
    (:set_reconnect_ivl,           :get_reconnect_ivl,           18,   ip)
    (:set_backlog,                 :get_backlog,                 19,   ip)
    (:set_reconnect_ivl_max,       :get_reconnect_ivl_max,       21,   ip)
  }

@unix_only opslist = vcat(opslist, (nothing,     :get_fd,        14,   ip))
@windows_only opslist = vcat(opslist, (nothing,  :get_fd,        14,   pp))

if version.major == 2
    opslist = vcat(opslist, {
    (:set_hwm,                     :get_hwm,                      1, u64p)
    (:set_swap,                    :get_swap,                     3, i64p)
    (:set_rate,                    :get_rate,                     8, i64p)
    (:set_recovery_ivl,            :get_recovery_ivl,             9, i64p)
    (:_zmq_setsockopt_mcast_loop,  :_zmq_getsockopt_mcast_loop,  10, i64p)
    (:set_sndbuf,                  :get_sndbuf,                  11, u64p)
    (:set_rcvbuf,                  :get_rcvbuf,                  12, u64p)
    (nothing,                      :_zmq_getsockopt_rcvmore,     13, i64p)
    (nothing,                      :get_events,                  15, u32p)
    (:set_recovery_ivl_msec,       :get_recovery_ivl_msec,       20, i64p)
    })
else
    opslist = vcat(opslist, {
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
    })
end
if version > v"2.1"
    opslist = vcat(opslist, {
    (:set_rcvtimeo,                :get_rcvtimeo,                27,   ip)
    (:set_sndtimeo,                :get_sndtimeo,                28,   ip)
    })
end
    
for (fset, fget, k, p) in opslist
    if fset != nothing
        @eval global ($fset)
        @eval function ($fset)(socket::Socket, option_val::Integer)
            ($p)[1] = option_val
            rc = ccall((:zmq_setsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{Void}, Uint),
                       socket.data, $k, $p, sizeof(eltype($p)))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
    end
    if fget != nothing
        @eval global($fget)
        @eval function ($fget)(socket::Socket)
            ($sz)[1] = sizeof(eltype($p))
            rc = ccall((:zmq_getsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{Void}, Ptr{Uint}),
                       socket.data, $k, $p, $sz)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return int(($p)[1])
        end
    end        
end
# For some functions, the publicly-visible versions should require &
# return boolean
if version.major == 2
    global set_mcast_loop
    set_mcast_loop(socket::Socket, val::Bool) = _zmq_setsockopt_mcast_loop(socket, val)
    global get_mcast_loop
    get_mcast_loop(socket::Socket) = bool(_zmq_getsockopt_mcast_loop(socket))
end
end  # let
# More functions with boolean prototypes
get_rcvmore(socket::Socket) = bool(_zmq_getsockopt_rcvmore(socket))
# And a convenience function
ismore(socket::Socket) = get_rcvmore(socket)


# Raw FD access
@unix_only fd(socket::Socket) = RawFD(get_fd(socket))
@windows_only fd(socket::Socket) = WindowsRawSocket(get_fd(socket))
wait(socket::Socket; readable=false, writeable=false) = wait(fd(socket); readable=readable, writeable=writeable)


# Socket options of string type
let u8ap = zeros(Uint8, 255), sz = zeros(Uint, 1)
opslist = {
    (:set_identity,                :get_identity,                5)
    (:set_subscribe,               nothing,                      6)
    (:set_unsubscribe,             nothing,                      7)
    }
if version.major >= 3
    opslist = vcat(opslist, {
    (nothing,                      :get_last_endpoint,          32)
    (:set_tcp_accept_filter,       nothing,                     38)
    })
end
for (fset, fget, k) in opslist
    if fset != nothing
        @eval global ($fset)
        @eval function ($fset)(socket::Socket, option_val::ByteString)
            if length(option_val) > 255
                throw(StateError("option value too large"))
            end
            rc = ccall((:zmq_setsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{Uint8}, Uint),
                       socket.data, $k, option_val, length(option_val))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end      
    end
    if fget != nothing
        @eval global ($fget)
        @eval function ($fget)(socket::Socket)
            ($sz)[1] = length($u8ap)
            rc = ccall((:zmq_getsockopt, zmq), Cint,
                       (Ptr{Void}, Cint, Ptr{Uint8}, Ptr{Uint}),
                       socket.data, $k, $u8ap, $sz)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return bytestring(convert(Ptr{Uint8}, $u8ap), int(($sz)[1]))
        end
    end        
end
end  # let
    


function bind(socket::Socket, endpoint::String)
    rc = ccall((:zmq_bind, zmq), Cint, (Ptr{Void}, Ptr{Uint8}), socket.data, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

function connect(socket::Socket, endpoint::String)
    rc=ccall((:zmq_connect, zmq), Cint, (Ptr{Void}, Ptr{Uint8}), socket.data, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end


## Messages ##
type Message <: AbstractArray{Uint8,1}
    # 32 bytes (for v3) + a pointer (for v2)
    w0::Int64
    w1::Int64
    w2::Int64
    w3::Int64
    w4::Int
    bufferorigin::Any # prevent source of buffer (if any) from being gc'ed

    # Create an empty message (for receive)
    function Message()
        zmsg = new()
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
        rc = ccall((:zmq_msg_init_size, zmq), Cint, (Ptr{Message}, Csize_t), &zmsg, len)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(zmsg, close)
        return zmsg
    end
    # Create a message with a given String or Array as a buffer (for send)
    Message(m::ByteString) = Message(m, convert(Ptr{Uint8}, m), length(m))
    function Message{T}(origin, m::Ptr{T}, len::Integer)
        zmsg = new()
        zmsg.bufferorigin = origin # should be origin of data pointed to by m
        rc = ccall((:zmq_msg_init_data, zmq), Cint, (Ptr{Message}, Ptr{T}, Csize_t, Ptr{Void}, Ptr{Void}), &zmsg, m, len*sizeof(T), C_NULL, C_NULL)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(zmsg, close)
        return zmsg
    end
    Message(m::ByteString) = Message(m, convert(Ptr{Uint8}, m), length(m))
    Message{T}(m::Array{T}) = Message(m, convert(Ptr{T}, m), length(m))
end

# AbstractArray behaviors:
similar(a::Message, T, dims::Dims) = Array(T, dims) # ?
length(zmsg::Message) = ccall((:zmq_msg_size, zmq), Csize_t, (Ptr{Message},) , &zmsg)
size(zmsg::Message) = (length(zmsg),)
stride(zmsg::Message, i::Integer) = i <= 1 ? 1 : length(zmsg)
convert(::Type{Ptr{Uint8}}, zmsg::Message) = ccall((:zmq_msg_data, zmq), Ptr{Uint8}, (Ptr{Message},), &zmsg)
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
bytestring(zmsg::Message) = bytestring(pointer(zmsg), length(zmsg))

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

@v3only begin
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
end # end v3only

## Send/receive messages
#
# Julia defines two types of ZMQ messages: "raw" and "serialized". A "raw"
# message is just a plain ZeroMQ message, used for sending a sequence
# of bytes. You send these with the following:
#   send(socket, zmsg)
#   zmsg = recv(socket)

@v2only begin
function send(socket::Socket, zmsg::Message, flag=int32(0))
    rc = ccall((:zmq_send, zmq), Cint, (Ptr{Void}, Ptr{Message}, Cint),
               socket.data, &zmsg, flag)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end
send(socket::Socket, msg::String, flag=int32(0)) =
  send(socket, Message(msg), flag)
send{T}(socket::Socket, msg::Array{T}, flag=int32(0)) =
  send(socket, Message(msg), flag)
end # end v2only

@v3only begin
function send(socket::Socket, zmsg::Message, flag=int32(0))
    if (get_events(socket) & POLLOUT) == 0
        wait(socket; writeable = true)
    end
    rc = ccall((:zmq_msg_send, zmq), Cint, (Ptr{Void}, Ptr{Message}, Cint),
                &zmsg, socket.data, flag)
    if rc == -1
        throw(StateError(jl_zmq_error_str()))
    end
end
function send{T}(socket::Socket, msg::Ptr{T}, len, flag=int32(0))
    if (get_events(socket) & POLLOUT) == 0
        wait(socket; writeable = true)
    end
    rc = ccall((:zmq_send, zmq), Cint, 
            (Ptr{Void}, Ptr{T}, Csize_t, Cint), 
            socket.data, msg, len * sizeof(T), flag)
    if rc == -1
        throw(StateError(jl_zmq_error_str()))
    end
end
send(socket::Socket, msg::String, flag=int32(0)) = send(socket, convert(Ptr{Uint8}, msg), length(msg), flag)
send{T}(socket::Socket, msg::Array{T}, flag=int32(0)) = send(socket, convert(Ptr{T}, msg), length(msg), flag)
end # end v3only

@v2only begin
function recv(socket::Socket, flag=int32(0))
    zmsg = Message()
    if (get_events(socket) & POLLIN) == 0
        wait(socket; readable = true)
    end
    rc = ccall((:zmq_recv, zmq), Cint, (Ptr{Void}, Ptr{Message}, Cint),
               socket.data, &zmsg, flag)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
    return zmsg
end
end # end v2only

@v3only begin
function recv(socket::Socket, flag=int32(0))
    zmsg = Message()
    if (get_events(socket) & POLLIN) == 0
        wait(socket; readable = true)
    end
    rc = ccall((:zmq_msg_recv, zmq), Cint, (Ptr{Message}, Ptr{Void}, Cint),
                &zmsg, socket.data, flag)
    if rc == -1
        throw(StateError(jl_zmq_error_str()))
    end
    return zmsg
end
end # end v3only

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

#Send/Recv Options
const NOBLOCK = 1
const DONTWAIT = 1
const SNDMORE = 2

#IO Multiplexing
const POLLIN = 1
const POLLOUT = 2
const POLLERR = 4

#Built in devices
const STREAMER = 1
const FORWARDER = 2
const QUEUE = 3

end
