## Sockets ##
mutable struct Socket
    data::Ptr{Cvoid}
    pollfd::_FDWatcher

    # ctx should be ::Context, but forward type references are not allowed
    function Socket(ctx, typ::Integer)
        p = ccall((:zmq_socket, libzmq), Ptr{Cvoid}, (Ptr{Cvoid}, Cint), ctx.data, typ)
        if p == C_NULL
            throw(StateError(jl_zmq_error_str()))
        end
        socket = new(p)
        socket.pollfd = _FDWatcher(fd(socket), #=readable=#true, #=writable=#false)
        @compat finalizer(close, socket)
        push!(ctx.sockets, WeakRef(socket))
        return socket
    end
    Socket(typ::Integer) = Socket(context(), typ)
end

function close(socket::Socket)
    if socket.data != C_NULL
        data = socket.data
        socket.data = C_NULL
        close(socket.pollfd, #=readable=#true, #=writable=#false)
        rc = ccall((:zmq_close, libzmq), Cint,  (Ptr{Cvoid},), data)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
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
    (nothing,                      :get_fd,                      14, Compat.Sys.iswindows() ? pp : ip)
    ]
    if fset != nothing
        @eval function ($fset)(socket::Socket, option_val::Integer)
            ($p)[1] = option_val
            rc = ccall((:zmq_setsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{Cvoid}, UInt),
                       socket.data, $k, $p, sizeof(eltype($p)))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
    end
    if fget != nothing
        @eval function ($fget)(socket::Socket)
            ($sz)[1] = sizeof(eltype($p))
            rc = ccall((:zmq_getsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{Cvoid}, Ptr{UInt}),
                       socket.data, $k, $p, $sz)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return Int(($p)[1])
        end
    end
end

# For some functions, the publicly-visible versions should require &
# return boolean:
get_rcvmore(socket::Socket) = Bool(_zmq_getsockopt_rcvmore(socket))
# And a convenience function
ismore(socket::Socket) = get_rcvmore(socket)

# subscribe/unsubscribe options take an arbitrary byte array
for (f,k) in ((:subscribe,6), (:unsubscribe,7))
    f_ = Symbol(f, "_")
    @eval begin
        function $f_(socket::Socket, filter::Ptr{T}, len::Integer) where {T}
            rc = ccall((:zmq_setsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{T}, UInt),
                       socket.data, $k, filter, len)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
        $f(socket::Socket, filter::Union{Array,AbstractString}) =
            @preserve filter $f_(socket, pointer(filter), sizeof(filter))
        $f(socket::Socket) = $f_(socket, C_NULL, 0)
    end
end

# Raw FD access
if Compat.Sys.isunix()
    fd(socket::Socket) = RawFD(get_fd(socket))
end
if Compat.Sys.iswindows()
    using Base.Libc: WindowsRawSocket
    fd(socket::Socket) = WindowsRawSocket(convert(Ptr{Cvoid}, get_fd(socket)))
end

wait(socket::Socket) = wait(socket.pollfd, readable=true, writable=false)
notify(socket::Socket) = uv_pollcb(socket.pollfd.handle, Int32(0), Int32(UV_READABLE))


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
            rc = ccall((:zmq_setsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{UInt8}, UInt),
                       socket.data, $k, option_val, length(option_val))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
    end
    if fget != nothing
        @eval function ($fget)(socket::Socket)
            ($sz)[1] = length($u8ap)
            rc = ccall((:zmq_getsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{UInt8}, Ptr{UInt}),
                       socket.data, $k, $u8ap, $sz)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return unsafe_string(unsafe_convert(Ptr{UInt8}, $u8ap), Int(($sz)[1]))
        end
    end
end

function bind(socket::Socket, endpoint::AbstractString)
    rc = ccall((:zmq_bind, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket.data, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

function connect(socket::Socket, endpoint::AbstractString)
    rc=ccall((:zmq_connect, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket.data, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end