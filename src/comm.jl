
## Send/receive messages.

############################################################################

msg_send(socket::Socket, zmsg::_MessageOrRef, flags::Integer) =
    ccall((:zmq_msg_send, libzmq), Cint, (Ref{_Message}, Ptr{Cvoid}, Cint), zmsg, socket, flags)
msg_send(socket::Socket, zmsg::Message, flags::Integer) =
    ccall((:zmq_msg_send, libzmq), Cint, (Ref{Message}, Ptr{Cvoid}, Cint), zmsg, socket, flags)

function _send(socket::Socket, zmsg, more::Bool=false)
    while true
        if -1 == msg_send(socket, zmsg, (ZMQ_SNDMORE*more) | ZMQ_DONTWAIT)
            zmq_errno() == EAGAIN || throw(StateError(jl_zmq_error_str()))
            while (socket.events & POLLOUT) == 0
                wait(socket)
            end
        else
            notify_is_expensive = !isempty(getfield(socket,:pollfd).notify.waitq)
            if notify_is_expensive
                socket.events != 0 && notify(socket)
            end
            break
        end
    end
end

# By default, we send using _Message objects, which are optimized for
# small messages and copy the data.    If the caller wants zero-copy communications,
# then should explicitly create a Message() object, a more heavyweight object
# that allows zero-copy access.

"""
    send(socket::Socket, data; more=false)

Send `data` over `socket`.  A `more=true` keyword argument can be passed
to indicate that `data` is a portion of a larger multipart message.
`data` can be any `isbits` type, a `Vector` of `isbits` elements, a
`String`, or a [`Message`](@ref) object to perform zero-copy sends
of large arrays.
"""
function Sockets.send(socket::Socket, data; more::Bool=false)
    zmsg = _MessageRef(data)
    try
        _send(socket, zmsg, more)
    finally
        close(zmsg)
    end
end

"""
    send(socket::Socket, zmsg::Message; more::Bool=false)

Zero-copy version of [`Sockets.send(socket, data)`](@ref) using a user-allocated
[`Message`](@ref).
"""
Sockets.send(socket::Socket, zmsg::Message; more::Bool=false) = _send(socket, zmsg, more)

import Sockets: send
@deprecate send(socket::Socket, data, more::Bool) send(socket, data; more=more)

function Sockets.send(f::Function, socket::Socket; more::Bool=false)
    io = IOBuffer()
    f(io)
    send(socket, take!(io); more=more)
end

############################################################################

msg_recv(socket::Socket, zmsg::_MessageOrRef, flags::Integer) =
    ccall((:zmq_msg_recv, libzmq), Cint, (Ref{_Message}, Ptr{Cvoid}, Cint), zmsg, socket, flags)
msg_recv(socket::Socket, zmsg::Message, flags::Integer) =
    ccall((:zmq_msg_recv, libzmq), Cint, (Ref{Message}, Ptr{Cvoid}, Cint), zmsg, socket, flags)

function _recv!(socket::Socket, zmsg)
    while true
        if -1 == msg_recv(socket, zmsg, ZMQ_DONTWAIT)
            zmq_errno() == EAGAIN || throw(StateError(jl_zmq_error_str()))
            while socket.events & POLLIN== 0
                wait(socket)
            end
        else
            notify_is_expensive = !isempty(getfield(socket,:pollfd).notify.waitq)
            if notify_is_expensive
                socket.events != 0 && notify(socket)
            end
            break
        end
    end
    return zmsg
end

"""
    recv(socket::Socket)

Return a `Message` object representing a message received from a ZMQ `Socket`
(without making a copy of the message data).
"""
Sockets.recv(socket::Socket) = _recv!(socket, Message())

"""
    recv(socket::Socket, ::Type{T})

Receive a message of type `T` (typically a `String`, `Vector{UInt8}`, or
[`isbits`](https://docs.julialang.org/en/v1/base/base/#Base.isbits) type)
from a ZMQ [`Socket`](@ref).  (Makes a copy of the message data; you can alternatively
use [`recv(socket)`](@ref) to work with zero-copy bytearray-like representation for
large messages.)

"""
function Sockets.recv(socket::Socket, ::Type{T}) where {T}
    zmsg = msg_init()
    try
        _recv!(socket, zmsg)
        return unsafe_copy(T, zmsg)
    finally
        close(zmsg)
    end
end
