"""
A ZMQ socket.

    Socket(typ::Integer)

Create a socket of a certain type.

---

    Socket(ctx::Context, typ::Integer)

Create a socket in a given context.

---

    Socket(f::Function, args...)

Do-block constructor.
"""
mutable struct Socket
    data::Ptr{Cvoid}
    pollfd::_FDWatcher

    """
        Socket(ctx::Context, typ::Integer)

    Create a socket in a given context.
    """
    function Socket(ctx::Context, typ::Integer)
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

    """
        Socket(typ::Integer)

    Create a socket of a certain type.
    """
    Socket(typ::Integer) = Socket(context(), typ)
end

"""
    Socket(f::Function, args...)

Do-block constructor.
"""
function Socket(f::Function, args...)
    socket = Socket(args...)
    try
        f(socket)
    finally
        close(socket)
    end
end

Base.unsafe_convert(::Type{Ptr{Cvoid}}, s::Socket) = getfield(s, :data)

"""
    Base.isopen(socket::Socket)
"""
Base.isopen(socket::Socket) = getfield(socket, :data) != C_NULL

"""
    Base.close(socket::Socket)
"""
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

"""
    Sockets.bind(socket::Socket, endpoint::AbstractString)

Bind the socket to an endpoint. Note that the endpoint must be formatted as
described
[here](http://api.zeromq.org/4-3:zmq-bind). e.g. `tcp://127.0.0.1:42000`.
"""
function Sockets.bind(socket::Socket, endpoint::AbstractString)
    rc = ccall((:zmq_bind, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

"""
    Sockets.connect(socket::Socket, endpoint::AbstractString)

Connect the socket to an endpoint.
"""
function Sockets.connect(socket::Socket, endpoint::AbstractString)
    rc=ccall((:zmq_connect, libzmq), Cint, (Ptr{Cvoid}, Ptr{UInt8}), socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end
