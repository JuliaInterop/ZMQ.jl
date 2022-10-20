include("_message.jl")

# in order to support zero-copy messages that share data with Julia
# arrays, we need to hold a reference to the Julia object in a dictionary
# until zeromq is done with the data, to prevent it from being garbage
# collected.  The gc_protect dictionary is keyed by a uv_async_t* pointer,
# used in uv_async_send to tell Julia to when zeromq is done with the data.
const gc_protect = Dict{Ptr{Cvoid},Any}()

# callback argument for AsyncCondition
gc_protect_cb(work) = (pop!(gc_protect, work.handle, nothing); Base.close(work))

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

"""
High-level Message object for sending/receiving ZMQ messages in shared buffers.

    Message()

Create an empty message (for receive).

---

    Message(len::Integer)

Create a message with a given buffer size (for send).

---

    Message(origin::Any, m::Ptr{T}, len::Integer) where {T}

Low-level function to create a message (for send) with an existing
data buffer, without making a copy.  The origin parameter should
be the Julia object that is the origin of the data, so that
we can hold a reference to it until ZMQ is done with the buffer.

---

    Message(m::String)

Create a message with a string as a buffer (for send). Note: the Message now
"owns" the string, it must not be resized, or even written to after the message
is sent.

---

    Message(p::SubString{String})

Create a message with a sub-string as a buffer (for send). Note: the same
ownership semantics as for [`Message(m::String)`](@ref) apply.

---

    Message(a::Array)

Create a message with an array as a buffer (for send). Note: the same
ownership semantics as for [`Message(m::String)`](@ref) apply.

---

    Message(io::IOBuffer)

Create a message with an
[`IOBuffer`](https://docs.julialang.org/en/v1/base/io-network/#Base.IOBuffer) as
a buffer (for send). Note: the same ownership semantics as for
[`Message(m::String)`](@ref) apply.
"""
mutable struct Message <: AbstractArray{UInt8,1}
    # Matching the declaration in the header: char _[64];
    w_padding::_Message
    handle::Ptr{Cvoid} # index into gc_protect, if any

    """
        Message()

    Create an empty message (for receive).
    """
    function Message()
        zmsg = new()
        setfield!(zmsg, :handle, C_NULL)
        rc = ccall((:zmq_msg_init, libzmq), Cint, (Ref{Message},), zmsg)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(close, zmsg)
        return zmsg
    end

    """
        Message(len::Integer)

    Create a message with a given buffer size (for send).
    """
    function Message(len::Integer)
        zmsg = new()
        setfield!(zmsg, :handle, C_NULL)
        rc = ccall((:zmq_msg_init_size, libzmq), Cint, (Ref{Message}, Csize_t), zmsg, len)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(close, zmsg)
        return zmsg
    end

    """
        Message(origin::Any, m::Ptr{T}, len::Integer) where {T}

    Low-level function to create a message (for send) with an existing
    data buffer, without making a copy.  The origin parameter should
    be the Julia object that is the origin of the data, so that
    we can hold a reference to it until ZMQ is done with the buffer.
    """
    function Message(origin::Any, m::Ptr{T}, len::Integer) where {T}
        zmsg = new()
        setfield!(zmsg, :handle, gc_protect_handle(origin))
        gc_free_fn_c = @cfunction(gc_free_fn, Cint, (Ptr{Cvoid}, Ptr{Cvoid}))
        rc = ccall((:zmq_msg_init_data, libzmq), Cint, (Ref{Message}, Ptr{T}, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}),
                   zmsg, m, len, gc_free_fn_c, getfield(zmsg, :handle))
        if rc != 0
            gc_free_fn(C_NULL, getfield(zmsg, :handle)) # don't leak memory on error
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(close, zmsg)
        return zmsg
    end

    """
        Message(m::String)

    Create a message with a string as a buffer (for send). Note: the Message now
    "owns" the string, it must not be resized, or even written to after the message
    is sent.
    """
    Message(m::String) = Message(m, pointer(m), sizeof(m))

    """
        Message(p::SubString{String})

    Create a message with a sub-string as a buffer (for send). Note: the same
    ownership semantics as for [`Message(m::String)`](@ref) apply.
    """
    Message(p::SubString{String}) =
        Message(p, pointer(p.string)+p.offset, sizeof(p))

    """
        Message(a::Array)

    Create a message with an array as a buffer (for send). Note: the same
    ownership semantics as for [`Message(m::String)`](@ref) apply.
    """
    Message(a::Array) = Message(a, pointer(a), sizeof(a))

    """
        Message(io::IOBuffer)

    Create a message with an
    [`IOBuffer`](https://docs.julialang.org/en/v1/base/io-network/#Base.IOBuffer) as
    a buffer (for send). Note: the same ownership semantics as for
    [`Message(m::String)`](@ref) apply.
    """
    function Message(io::IOBuffer)
        if !io.readable || !io.seekable
            error("byte read failed")
        end
        Message(io.data)
    end
end

# check whether zeromq has called our free-function, i.e. whether
# we are save to reclaim ownership of any buffer object
isfreed(m::Message) = haskey(gc_protect, getfield(m, :handle))

# AbstractArray behaviors:
Base.similar(a::Message, ::Type{T}, dims::Dims) where {T} = Array{T}(undef, dims) # ?
Base.length(zmsg::Message) = Int(ccall((:zmq_msg_size, libzmq), Csize_t, (Ref{Message},), zmsg))
Base.size(zmsg::Message) = (length(zmsg),)
Base.unsafe_convert(::Type{Ptr{UInt8}}, zmsg::Message) = ccall((:zmq_msg_data, libzmq), Ptr{UInt8}, (Ref{Message},), zmsg)
function Base.getindex(a::Message, i::Integer)
    @boundscheck if i < 1 || i > length(a)
        throw(BoundsError())
    end
    @preserve a unsafe_load(pointer(a), i)
end
function Base.setindex!(a::Message, v, i::Integer)
    @boundscheck if i < 1 || i > length(a)
        throw(BoundsError())
    end
    @preserve a unsafe_store!(pointer(a), v, i)
    return v
end

# Convert message to string (copies data)
Base.unsafe_string(zmsg::Message) = @preserve zmsg unsafe_string(pointer(zmsg), length(zmsg))

Base.elsize(::Message) = 1
Base.strides(::Message) = (1,)

# Build an IOStream from a message
# Copies the data
function Base.convert(::Type{IOStream}, zmsg::Message)
    s = IOBuffer()
    write(s, zmsg)
    return s
end

# Close a message. You should not need to call this manually (let the
# finalizer do it).
function Base.close(zmsg::Message)
    rc = ccall((:zmq_msg_close, libzmq), Cint, (Ref{Message},), zmsg)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
    return nothing
end

function _get(zmsg::Message, property::Integer)
    val = ccall((:zmq_msg_get, libzmq), Cint, (Ref{Message}, Cint), zmsg, property)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    val
end
function _set(zmsg::Message, property::Integer, value::Integer)
    rc = ccall((:zmq_msg_set, libzmq), Cint, (Ref{Message}, Cint, Cint), zmsg, property, value)
    if rc < 0
        throw(StateError(jl_zmq_error_str()))
    end
end
Base.propertynames(zmsg::Message) = (:more,)
function Base.getproperty(zmsg::Message, name::Symbol)
    if name === :more
        return _get(zmsg, MORE)
    else
        error("Message has no field $name")
    end
end
function Base.setproperty!(zmsg::Message, name::Symbol, value::Integer)
    # Currently the zmq_msg_set() function does not support any property names
    error("Message has no writable field $name")
end
function Base.get(zmsg::Message, option::Integer)
    Base.depwarn("get(zmsg, option) is deprecated; use zmsg.option instead", :get)
    return _get(zmsg, option)
end
@deprecate set(zmsg::Message, property::Integer, value::Integer) _set(zmsg, property, value)
