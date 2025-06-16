export PollItems, poll

"""
    PollItems(socks::AbstractVector{Socket}, events::AbstractVector{T}) where {T<:Integer}
    PollItems(sock_event_pairs::AbstractVector{Tuple{Socket, T}) where {T<:Integer}

High-level `PollItems` object for polling multiple ZMQ sockets simultaneously.
It is recommended poll via this object since the low-level API is unsafe.

Events are specified as bitmasks, see the [libzmq documentation](https://libzmq.readthedocs.io/en/latest/zmq_poll.html).
"""
struct PollItems
    inner::Vector{lib.zmq_pollitem_t}
    sock::Vector{Socket}

    function PollItems(
            socks::AbstractVector{Socket},
            events::AbstractVector{T}
        ) where {T <: Integer}
        return PollItems(convert(Vector{Socket}, socks), convert(Vector{T}, events))
    end

    function PollItems(v::AbstractVector{Tuple{Socket, T}}) where {T <: Integer}
        return PollItems(first.(v), last.(v))
    end

    function PollItems(
            socks::Vector{Socket},
            events::Vector{<:Integer}
        )
        @assert length(socks) == length(events)
        return new(
            map(
                (sock, event) ->
                lib.zmq_pollitem_t(Base.unsafe_convert(Ptr{Cvoid}, sock), -1, Int16(event), Int16(0)),
                socks, events
            ), socks
        )
    end
end

function poll(pitems::Vector{lib.zmq_pollitem_t}, sock::AbstractVector{Socket}, timeout = -1)
    return GC.@preserve sock begin
        lib.zmq_poll(pitems, Cint(length(pitems)), Clong(timeout))
    end
end

function poll(pitems::AbstractVector{lib.zmq_pollitem_t}, sock::AbstractVector{Socket}, timeout = -1)
    return poll(convert(Vector{lib.zmq_pollitem_t}, pitems), sock, timeout)
end

"""
    poll(p::PollItems, timeout::Integer = -1)
Poll multiple sockets and return the amount of events. The timeout is specified in milliseconds. A negative timeout blocks indefinitely.
"""
function poll(p::PollItems, timeout = -1)
    return poll(p.inner, p.sock, timeout)
end

"""
    revents(p::PollItems)::Vector{Int16}
Return all events for each socket. Allocates a new vector
"""
function revents(p::PollItems)
    return map(item -> item.revents, p.inner)
end

"""
    revents!(buffer::Vector{T}, p::PollItems) where {T<:Integer}
Store socket events in buffer. See also [`revents`](@ref)
"""
function revents!(buffer::AbstractVector{T}, p::PollItems) where {T <: Integer}
    for (i, j) in Iterators.zip(eachindex(p.inner), eachindex(buffer))
        buffer[j] = p.inner[i].revents
    end
    return
end
