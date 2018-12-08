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
        setfield!(socket, :pollfd, _FDWatcher(fd(socket), #=readable=#true, #=writable=#false))
        finalizer(close, socket)
        push!(getfield(ctx, :sockets), WeakRef(socket))
        return socket
    end
    Socket(typ::Integer) = Socket(context(), typ)
end

Base.unsafe_convert(::Type{Ptr{Cvoid}}, s::Socket) = getfield(s, :data)

Base.isopen(socket::Socket) = getfield(socket, :data) != C_NULL
function Base.close(socket::Socket)
    if isopen(socket)
        close(getfield(socket, :pollfd), #=readable=#true, #=writable=#false)
        rc = ccall((:zmq_close, libzmq), Cint,  (Ptr{Cvoid},), socket)
        setfield!(socket, :data, C_NULL)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
    end
end

# Raw FD access
if Sys.isunix()
    Base.fd(socket::Socket) = RawFD(socket.fd)
end
if Sys.iswindows()
    using Base.Libc: WindowsRawSocket
    Base.fd(socket::Socket) = WindowsRawSocket(convert(Ptr{Cvoid}, socket.fd))
end

Base.wait(socket::Socket) = wait(getfield(socket, :pollfd), readable=true, writable=false)
Base.notify(socket::Socket) = @preserve socket uv_pollcb(getfield(socket, :pollfd).handle, Int32(0), Int32(UV_READABLE))

function bind(socket::Socket, endpoint::AbstractString)
    rc = ccall((:zmq_bind, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end
function Sockets.bind(socket::Socket, endpoint::AbstractString)
    depwarn("Sockets.bind(socket::Socket, endpoint::AbstractString) is deprecated, use bind(socket::Socket, endpoint::AbstractString) insead.", nothing)
    bind(socket, endpoint)
end

function connect(socket::Socket, endpoint::AbstractString)
    rc=ccall((:zmq_connect, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

function Sockets.connect(socket::Socket, endpoint::AbstractString)
    depwarn("Sockets.connect(socket::Socket, endpoint::AbstractString) is deprecated, use connect(socket::Socket, endpoint::AbstractString) insead.", nothing)
    connect(socket, endpoint)
end
