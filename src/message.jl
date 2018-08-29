

# in order to support zero-copy messages that share data with Julia
# arrays, we need to hold a reference to the Julia object in a dictionary
# until zeromq is done with the data, to prevent it from being garbage
# collected.  The gc_protect dictionary is keyed by a uv_async_t* pointer,
# used in uv_async_send to tell Julia to when zeromq is done with the data.
const gc_protect = Dict{Ptr{Cvoid},Any}()
# 0.2 compatibility
gc_protect_cb(work, status) = gc_protect_cb(work)
close_handle(work) = Base.close(work)
gc_protect_cb(work) = (pop!(gc_protect, work.handle, nothing); close_handle(work))

function gc_protect_handle(obj::Any)
    work = Base.AsyncCondition(gc_protect_cb)
    gc_protect[work.handle] = (work,obj)
    work.handle
end

# Thread-safe zeromq callback when data is freed, passed to zmq_msg_init_data.
# The hint parameter will be a uv_async_t* pointer.
function gc_free_fn(data::Ptr{Cvoid}, hint::Ptr{Cvoid})
    ccall(:uv_async_send,Cint,(Ptr{Cvoid},),hint)
end

## Messages ##
@compat primitive type MsgPadding 64 * 8 end

mutable struct Message <: AbstractArray{UInt8,1}
    # Matching the declaration in the header: char _[64];
    w_padding::MsgPadding
    handle::Ptr{Cvoid} # index into gc_protect, if any

    # Create an empty message (for receive)
    function Message()
        zmsg = new()
        zmsg.handle = C_NULL
        # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
        rc = ccall((:zmq_msg_init, libzmq), Cint, (Any,), zmsg)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        @compat finalizer(close, zmsg)
        return zmsg
    end
    # Create a message with a given buffer size (for send)
    function Message(len::Integer)
        zmsg = new()
        zmsg.handle = C_NULL
        # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
        rc = ccall((:zmq_msg_init_size, libzmq), Cint, (Any, Csize_t), zmsg, len)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        @compat finalizer(close, zmsg)
        return zmsg
    end

    # low-level function to create a message (for send) with an existing
    # data buffer, without making a copy.  The origin parameter should
    # be the Julia object that is the origin of the data, so that
    # we can hold a reference to it until zeromq is done with the buffer.
    function Message(origin::Any, m::Ptr{T}, len::Integer) where {T}
        zmsg = new()
        zmsg.handle = gc_protect_handle(origin)
        # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
        rc = ccall((:zmq_msg_init_data, libzmq), Cint, (Any, Ptr{T}, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}),
                   zmsg, m, len, gc_free_fn_c[], zmsg.handle)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        @compat finalizer(close, zmsg)
        return zmsg
    end

    # Create a message with a given AbstractString or Array as a buffer (for send)
    # (note: now "owns" the buffer ... the Array must not be resized,
    #        or even written to after the message is sent!)
    Message(m::String) = Message(m, unsafe_convert(Ptr{UInt8}, pointer(m)), sizeof(m))
    Message(p::SubString{String}) =
        Message(p, pointer(p.string)+p.offset, sizeof(p))
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
similar(a::Message, ::Type{T}, dims::Dims) where {T} = Array{T}(undef, dims) # ?
# TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
length(zmsg::Message) = Int(ccall((:zmq_msg_size, libzmq), Csize_t, (Any,), zmsg))
size(zmsg::Message) = (length(zmsg),)
# TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
unsafe_convert(::Type{Ptr{UInt8}}, zmsg::Message) = ccall((:zmq_msg_data, libzmq), Ptr{UInt8}, (Any,), zmsg)
function getindex(a::Message, i::Integer)
    @boundscheck if i < 1 || i > length(a)
        throw(BoundsError())
    end
    @preserve a unsafe_load(pointer(a), i)
end
function setindex!(a::Message, v, i::Integer)
    @boundscheck if i < 1 || i > length(a)
        throw(BoundsError())
    end
    @preserve a unsafe_store!(pointer(a), v, i)
end

# Convert message to string (copies data)
unsafe_string(zmsg::Message) = @preserve zmsg unsafe_string(pointer(zmsg), length(zmsg))

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
    # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
    rc = ccall((:zmq_msg_close, libzmq), Cint, (Any,), zmsg)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

function get(zmsg::Message, property::Integer)
    # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
    val = ccall((:zmq_msg_get, libzmq), Cint, (Any, Cint), zmsg, property)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    val
end
function set(zmsg::Message, property::Integer, value::Integer)
    # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
    rc = ccall((:zmq_msg_set, libzmq), Cint, (Any, Cint, Cint), zmsg, property, value)
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

function send(socket::Socket, zmsg::Message, SNDMORE::Bool=false)
    while true
        # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
        rc = ccall((:zmq_msg_send, libzmq), Cint, (Any, Ptr{Cvoid}, Cint),
                    zmsg, socket.data, (ZMQ_SNDMORE*SNDMORE) | ZMQ_DONTWAIT)
        if rc == -1
            zmq_errno() == EAGAIN || throw(StateError(jl_zmq_error_str()))
            while (get_events(socket) & POLLOUT) == 0
                wait(socket)
            end
        else
            notify_is_expensive = !isempty(socket.pollfd.notify.waitq)
            if notify_is_expensive
                get_events(socket) != 0 && notify(socket)
            end
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
        # TODO: change `Any` to `Ref{Message}` when 0.6 support is dropped.
        rc = ccall((:zmq_msg_recv, libzmq), Cint, (Any, Ptr{Cvoid}, Cint),
                    zmsg, socket.data, ZMQ_DONTWAIT)
        if rc == -1
            zmq_errno() == EAGAIN || throw(StateError(jl_zmq_error_str()))
            while (get_events(socket) & POLLIN) == 0
                wait(socket)
            end
        else
            notify_is_expensive = !isempty(socket.pollfd.notify.waitq)
            if notify_is_expensive
                get_events(socket) != 0 && notify(socket)
            end
            break
        end
    end
    return zmsg
end