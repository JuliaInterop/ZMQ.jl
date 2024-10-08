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
    mutable struct Message <: AbstractArray{UInt8, 1}

High-level `Message` object for sending/receiving ZMQ messages in shared
buffers. As an `AbstractArray`, it supports common (non-resizeable) array
behaviour.

# Examples
```jldoctest
julia> using ZMQ

julia> m = Message("foo");

julia> Char(m[1])            # Array indexing
'f': ASCII/Unicode U+0066 (category Ll: Letter, lowercase)

julia> m[end] = Int('g');    # Array assignment

julia> unsafe_string(m)      # Conversion to string (only do this if you know the message is a string)
"fog"

julia> IOBuffer(m)           # Create a zero-copy IOBuffer
IOBuffer(data=UInt8[...], readable=true, writable=false, seekable=true, append=false, size=3, maxsize=Inf, ptr=1, mark=-1)
```
"""
mutable struct Message <: AbstractArray{UInt8, 1}
    # Matching the declaration in the header: char _[64];
    w_padding::_Message
    handle::Ptr{Cvoid} # index into gc_protect, if any

    @doc """
        Message()

    Create an empty message (for receive).
    """
    function Message()
        zmsg = new()
        setfield!(zmsg, :handle, C_NULL)
        rc = lib.zmq_msg_init(zmsg)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(close, zmsg)
        return zmsg
    end

    @doc """
        Message(len::Integer)

    Create a message with a given buffer size (for send).
    """
    function Message(len::Integer)
        zmsg = new()
        setfield!(zmsg, :handle, C_NULL)
        rc = lib.zmq_msg_init_size(zmsg, len)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(close, zmsg)
        return zmsg
    end

    @doc """
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
        rc = lib.zmq_msg_init_data(zmsg, m, len, gc_free_fn_c, getfield(zmsg, :handle))
        if rc != 0
            gc_free_fn(C_NULL, getfield(zmsg, :handle)) # don't leak memory on error
            throw(StateError(jl_zmq_error_str()))
        end
        finalizer(close, zmsg)
        return zmsg
    end

    @doc """
        Message(m::String)

    Create a message with a string as a buffer (for send). Note: the Message now
    "owns" the string, it must not be resized, or even written to after the message
    is sent.
    """
    Message(m::String) = Message(m, pointer(m), sizeof(m))

    @doc """
        Message(p::SubString{String})

    Create a message with a sub-string as a buffer (for send). Note: the same
    ownership semantics as for [`Message(m::String)`](@ref) apply.
    """
    Message(p::SubString{String}) =
        Message(p, pointer(p.string)+p.offset, sizeof(p))

    @doc """
        Message(a::T) where T <: DenseVector

    Create a message with an array as a buffer (for send). Note: the same
    ownership semantics as for [`Message(m::String)`](@ref) apply.

    Usually `a` will be a 1D `Array`/`Vector`, but on Julia 1.11+ it can also be
    a `Memory`.
    """
    Message(a::T) where T <: DenseVector = Message(a, pointer(a), sizeof(a))

    @doc """
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

"""
    isfreed(m::Message)

Check whether zeromq has called our free-function, i.e. whether we are safe to
reclaim ownership of any buffer object the [`Message`](@ref) was created with.
"""
isfreed(m::Message) = !haskey(gc_protect, getfield(m, :handle))

# AbstractArray behaviors:
Base.similar(a::Message, ::Type{T}, dims::Dims) where {T} = Array{T}(undef, dims) # ?
Base.length(zmsg::Message) = Int(lib.zmq_msg_size(zmsg))
Base.size(zmsg::Message) = (length(zmsg),)
Base.unsafe_convert(::Type{Ptr{UInt8}}, zmsg::Message) = Ptr{UInt8}(lib.zmq_msg_data(zmsg))
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
    Base.depwarn("convert(IOStream, ::Message) is deprecated, use `IOBuffer(zmsg)` instead to make a zero-copy IOBuffer from a Message.", :convert)
    s = IOBuffer()
    write(s, zmsg)
    return s
end

# Close a message. You should not need to call this manually (let the
# finalizer do it).
function Base.close(zmsg::Message)
    rc = lib.zmq_msg_close(zmsg)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
    return nothing
end

function _get(zmsg::Message, property::Integer)
    val = lib.zmq_msg_get(zmsg, property)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    val
end
function _set(zmsg::Message, property::Integer, value::Integer)
    rc = lib.zmq_msg_set(zmsg, property, value)
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
