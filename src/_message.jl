## Low-level _Message type for sending/receiving small ZMQ messages directly, without the complications
## and overhead of the Message object for sharing buffers between Julia and libzmq.

# Low-level message type, matching the declaration of
# zmq_msg_t in the header: char _[64];
primitive type _Message 64 * 8 end

const _MessageOrRef = Union{_Message,Base.RefValue{_Message}}

function msg_init()
    zmsg = Ref{_Message}()
    rc = ccall((:zmq_msg_init, libzmq), Cint, (Ref{_Message},), zmsg)
    rc != 0 && throw(StateError(jl_zmq_error_str()))
    return zmsg
end

function msg_init(nbytes::Int)
    zmsg = Ref{_Message}()
    rc = ccall((:zmq_msg_init_size, libzmq), Cint, (Ref{_Message}, Csize_t), zmsg, nbytes % Csize_t)
    rc != 0 && throw(StateError(jl_zmq_error_str()))
    return zmsg
end

# note: no finalizer for _Message, so we need to call close manually!
function Base.close(zmsg::_MessageOrRef)
    rc = ccall((:zmq_msg_close, libzmq), Cint, (Ref{_Message},), zmsg)
    rc != 0 && throw(StateError(jl_zmq_error_str()))
    return nothing
end

Base.length(zmsg::_MessageOrRef) = ccall((:zmq_msg_size, libzmq), Csize_t, (Ref{_Message},), zmsg) % Int
Base.unsafe_convert(::Type{Ptr{UInt8}}, zmsg::_MessageOrRef) =
    ccall((:zmq_msg_data, libzmq), Ptr{UInt8}, (Ref{_Message},), zmsg)

# isbits data, vectors thereof, and strings can be converted to/from _Message

function _MessageRef(x::T) where {T}
    isbitstype(T) || throw(MethodError(_MessageRef, (x,)))
    n = sizeof(x)
    zmsg = msg_init(n)
    @preserve zmsg unsafe_store!(Ptr{T}(Base.unsafe_convert(Ptr{UInt8}, zmsg)), x)
    return zmsg
end

function _MessageRef(x::Vector{T}) where {T}
    isbitstype(T) || throw(MethodError(_MessageRef, (x,)))
    n = sizeof(x)
    zmsg = msg_init(n)
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{UInt8}, Ptr{T}, Csize_t), zmsg, x, n)
    return zmsg
end

function _MessageRef(x::String)
    n = sizeof(x)
    zmsg = msg_init(n)
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{UInt8}, Ptr{UInt8}, Csize_t), zmsg, x, n)
    return zmsg
end

function unsafe_copy(::Type{Vector{T}}, zmsg::_MessageOrRef) where {T}
    isbitstype(T) || throw(MethodError(unsafe_copy, (T, zmsg,)))
    n = length(zmsg)
    len, remainder = divrem(n, sizeof(T))
    iszero(remainder) || error("message length $n not a multiple of sizeof($T)")
    a = Array{T}(undef, len)
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{T}, Ptr{UInt8}, Csize_t), a, zmsg, n)
    return a
end

function unsafe_copy(::Type{T}, zmsg::_MessageOrRef) where {T}
    isbitstype(T) || throw(MethodError(unsafe_copy, (T, zmsg,)))
    n = length(zmsg)
    n == sizeof(T) || error("message length $n ≠ sizeof($T)")
    return @preserve zmsg unsafe_load(Ptr{T}(Base.unsafe_convert(Ptr{UInt8}, zmsg)))
end

function unsafe_copy(::Type{String}, zmsg::_MessageOrRef)
    n = length(zmsg)
    return @preserve zmsg unsafe_string(Base.unsafe_convert(Ptr{UInt8}, zmsg), n)
end

unsafe_copy(::Type{IOBuffer}, zmsg::_MessageOrRef) = IOBuffer(unsafe_copy(Vector{UInt8}, zmsg))
