"""
A ZMQ socket.
"""
mutable struct Socket
    data::Ptr{Cvoid}
    context::Context
    pollfd::FDWatcher

    @doc """
        Socket(ctx::Context, typ::Integer)

    Create a socket in a given context.
    """
    function Socket(ctx::Context, typ::Integer)
        p = lib.zmq_socket(ctx, typ)
        if p == C_NULL
            throw(StateError(jl_zmq_error_str()))
        end
        socket = new(p, ctx)
        setfield!(socket, :pollfd, FDWatcher(fd(socket), #=readable=#true, #=writable=#false))
        finalizer(close, socket)
        push!(getfield(ctx, :sockets), WeakRef(socket))
        return socket
    end

    @doc """
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

const _socket_type_names = Dict(
    lib.ZMQ_PAIR => "PAIR",
    lib.ZMQ_PUB => "PUB",
    lib.ZMQ_SUB => "SUB",
    lib.ZMQ_REQ => "REQ",
    lib.ZMQ_REP => "REP",
    lib.ZMQ_DEALER => "DEALER",
    lib.ZMQ_ROUTER => "ROUTER",
    lib.ZMQ_PULL => "PULL",
    lib.ZMQ_PUSH => "PUSH",
    lib.ZMQ_XPUB => "XPUB",
    lib.ZMQ_XSUB => "XSUB"
)

function Base.show(io::IO, socket::Socket)
    if isopen(socket)
        type_name = _socket_type_names[socket.type]
        last_endpoint = socket.last_endpoint == "\0" ? "" : ", $(socket.last_endpoint)"
        print(io, Socket, "($(type_name)$(last_endpoint))")
    else
        print(io, Socket, "([closed])")
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
        close(getfield(socket, :pollfd))
        rc = lib.zmq_close(socket)
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

Base.wait(socket::Socket) = wait(getfield(socket, :pollfd))
Base.notify(socket::Socket) = @preserve socket uv_pollcb(getfield(socket, :pollfd).watcher.handle, Int32(0), Int32(UV_READABLE))

"""
    Sockets.bind(socket::Socket, endpoint::AbstractString)

Bind the socket to an endpoint. Note that the endpoint must be formatted as
described
[here](http://api.zeromq.org/4-3:zmq-bind). e.g. `tcp://127.0.0.1:42000`.
"""
function Sockets.bind(socket::Socket, endpoint::AbstractString)
    rc = lib.zmq_bind(socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

"""
    Sockets.connect(socket::Socket, endpoint::AbstractString)

Connect the socket to an endpoint.
"""
function Sockets.connect(socket::Socket, endpoint::AbstractString)
    rc = lib.zmq_connect(socket, endpoint)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end
