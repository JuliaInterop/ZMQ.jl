# Socket options

for (fset, fget, k, T) in [
    (:set_affinity,                :get_affinity,                 4, UInt64)
    (:set_type,                    :get_type,                    16,   Cint)
    (:set_linger,                  :get_linger,                  17,   Cint)
    (:set_reconnect_ivl,           :get_reconnect_ivl,           18,   Cint)
    (:set_backlog,                 :get_backlog,                 19,   Cint)
    (:set_reconnect_ivl_max,       :get_reconnect_ivl_max,       21,   Cint)
    (:set_rate,                    :get_rate,                     8,   Cint)
    (:set_recovery_ivl,            :get_recovery_ivl,             9,   Cint)
    (:set_sndbuf,                  :get_sndbuf,                  11,   Cint)
    (:set_rcvbuf,                  :get_rcvbuf,                  12,   Cint)
    (nothing,                      :_zmq_getsockopt_rcvmore,     13,   Cint)
    (nothing,                      :get_events,                  15,   Cint)
    (:set_maxmsgsize,              :get_maxmsgsize,              22,   Cint)
    (:set_sndhwm,                  :get_sndhwm,                  23,   Cint)
    (:set_rcvhwm,                  :get_rcvhwm,                  24,   Cint)
    (:set_multicast_hops,          :get_multicast_hops,          25,   Cint)
    (:set_ipv4only,                :get_ipv4only,                31,   Cint)
    (:set_tcp_keepalive,           :get_tcp_keepalive,           34,   Cint)
    (:set_tcp_keepalive_idle,      :get_tcp_keepalive_idle,      35,   Cint)
    (:set_tcp_keepalive_cnt,       :get_tcp_keepalive_cnt,       36,   Cint)
    (:set_tcp_keepalive_intvl,     :get_tcp_keepalive_intvl,     37,   Cint)
    (:set_rcvtimeo,                :get_rcvtimeo,                27,   Cint)
    (:set_sndtimeo,                :get_sndtimeo,                28,   Cint)
    (nothing,                      :get_fd,                      14, Sys.iswindows() ? Ptr{Cvoid} : Cint)
    ]
    if fset != nothing
        @eval function $(Symbol("_",fset))(socket::Socket, option_val::Integer)
            rc = ccall((:zmq_setsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ref{$T}, Csize_t),
                       socket, $k, option_val, sizeof($T))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
        prop = QuoteNode(Symbol(String(fset)[5:end]))
        @eval @deprecate $fset(socket::Socket, option_val::Integer) setproperty!(socket, $prop, option_val)
    end
    if fget != nothing
        @eval function $(Symbol("_",fget))(socket::Socket)
            val = Ref{$T}()
            rc = ccall((:zmq_getsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ref{$T}, Ref{Csize_t}),
                       socket, $k, val, sizeof($T))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return Int(val[])
        end
        prop = QuoteNode(Symbol(String(fget)[5:end]))
        @eval @deprecate $fget(socket::Socket) getproperty(socket, $prop)
    end
end

# For some functions, the publicly-visible versions should require &
# return boolean:
_get_rcvmore(socket::Socket) = Bool(__zmq_getsockopt_rcvmore(socket))
@deprecate get_rcvmore(socket::Socket) getproperty(socket, :rcvmore)
@deprecate ismore(socket::Socket) getproperty(socket, :rcvmore)

# subscribe/unsubscribe options take an arbitrary byte array
for (f,k) in ((:subscribe,6), (:unsubscribe,7))
    f_ = Symbol(f, "_")
    @eval begin
        function $f_(socket::Socket, filter::Ptr{T}, len::Integer) where {T}
            rc = ccall((:zmq_setsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{T}, Csize_t),
                       socket, $k, filter, len)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
        $f(socket::Socket, filter::Union{Vector{UInt8},String}) =
            @preserve filter $f_(socket, pointer(filter), sizeof(filter))
        $f(socket::Socket, filter::AbstractString) = $f(socket, String(filter))
        $f(socket::Socket) = $f_(socket, C_NULL, 0)
    end
end

# Socket options of string type
for (fset, fget, k) in [
    (:_set_identity,                :_get_identity,                5)
    (:_set_subscribe,               nothing,                      6)
    (:_set_unsubscribe,             nothing,                      7)
    (nothing,                      :_get_last_endpoint,          32)
    (:_set_tcp_accept_filter,       nothing,                     38)
    ]
    if fset != nothing
        @eval function ($fset)(socket::Socket, option_val::String)
            if sizeof(option_val) > 255
                throw(StateError("option value too large"))
            end
            rc = ccall((:zmq_setsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{UInt8}, Csize_t),
                       socket, $k, option_val, sizeof(option_val))
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
        end
        @eval ($fset)(socket::Socket, option_val::AbstractString) = $fset(socket, String(option_val))
    end
    if fget != nothing
        @eval function ($fget)(socket::Socket)
            buf = Base.StringVector(255)
            len = Ref{Csize_t}(sizeof(buf))
            rc = ccall((:zmq_getsockopt, libzmq), Cint,
                       (Ptr{Cvoid}, Cint, Ptr{UInt8}, Ref{Csize_t}),
                       socket, $k, buf, len)
            if rc != 0
                throw(StateError(jl_zmq_error_str()))
            end
            return String(resize!(buf, len[]))
        end
    end
end
@deprecate get_identity(socket::Socket) getproperty(socket, :identity)
@deprecate set_identity(socket::Socket, val) setproperty!(socket, :identity, val)

# getproperty/setproperty API for socket properties
const sockprops = (:affinity, :type, :linger, :reconnect_ivl, :backlog, :reconnect_ivl_max,
                   :rate, :recovery_ivl, :sndbuf, :rcvbuf, :rcvmore, :events, :maxmsgsize,
                   :sndhwm, :rcvhwm, :multicast_hops, :ipv4only, :tcp_keepalive,
                   :tcp_keepalive_idle, :tcp_keepalive_intvl, :rcvtimeo, :fd, :identity,
                   :subscribe, :unsubscribe, :last_endpoint, :tcp_accept_filter)

Base.propertynames(::Socket) = sockprops

let ex = :(error("Socket has no field ", name))
    # build up the body of getproperty, of the form
    #     if name === :affinity
    #         get_affinity(sock)
    #     elseif ...
    for prop in sockprops
        getprop = Symbol("_get_", prop)
        if isdefined(@__MODULE__, getprop)
            ex = Expr(:elseif, :(name === $(QuoteNode(prop))), :($getprop(sock)), ex)
        end
    end
    ex = Expr(:if, ex.args...)
    @eval function Base.getproperty(sock::Socket, name::Symbol)
        $ex
    end
end

let ex = :(error("Socket has no field ", name))
    # build up the body of setproperty!, of the form
    #     if name === :affinity
    #         set_affinity(sock, val)
    #     elseif ...
    for prop in sockprops
        setprop = Symbol("_set_", prop)
        if isdefined(@__MODULE__, setprop)
            ex = Expr(:elseif, :(name === $(QuoteNode(prop))), :($setprop(sock, x)), ex)
        end
    end
    ex = Expr(:if, ex.args...)
    @eval function Base.setproperty!(sock::Socket, name::Symbol, x)
        $ex
        return x
    end
end