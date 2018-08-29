## Sockets ##
mutable struct Socket
    data::Ptr{Cvoid}
    pollfd::_FDWatcher

    # ctx should be ::Context, but forward type references are not allowed
    function Socket(ctx, typ::Integer)
        p = ccall((:zmq_socket, libzmq), Ptr{Cvoid}, (Ptr{Cvoid}, Cint), ctx, typ)
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

Base.unsafe_convert(::Type{Ptr{Cvoid}}, s::Socket) = s.data

function Base.close(socket::Socket)
    if socket.data != C_NULL
        close(socket.pollfd, #=readable=#true, #=writable=#false)
        rc = ccall((:zmq_close, libzmq), Cint,  (Ptr{Cvoid},), socket)
        socket.data = C_NULL
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
    end
end

# Raw FD access
if Compat.Sys.isunix()
    Base.fd(socket::Socket) = RawFD(get_fd(socket))
end
if Compat.Sys.iswindows()
    using Base.Libc: WindowsRawSocket
    Base.fd(socket::Socket) = WindowsRawSocket(convert(Ptr{Cvoid}, get_fd(socket)))
end

Base.wait(socket::Socket) = wait(socket.pollfd, readable=true, writable=false)
Base.notify(socket::Socket) = @preserve socket uv_pollcb(socket.pollfd.handle, Int32(0), Int32(UV_READABLE))

function Compat.Sockets.bind(socket::Socket, endpoint::AbstractString)
    rc = ccall((:zmq_bind, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

function Compat.Sockets.connect(socket::Socket, endpoint::AbstractString)
    rc=ccall((:zmq_connect, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end