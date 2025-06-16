export PollItems, poll

struct PollItems
    inner::Vector{lib.zmq_pollitem_t}
    sock::Vector{Socket}

    function PollItems(
            socks::AbstractVector{Socket},
            flags::AbstractVector{T}
        ) where {T <: Integer}
        return PollItems(convert(Vector{Socket}, socks), convert(Vector{T}, flags))
    end
    function PollItems(v::AbstractVector{Tuple{Socket, T}}) where {T <: Integer}
        return PollItems(first.(v), last.(v))
    end
    function PollItems(
            socks::Vector{Socket},
            flags::Vector{<:Integer}
        )
        @assert length(socks) == length(flags)
        return new(
            map(
                (sock, flag) ->
                lib.zmq_pollitem_t(Base.unsafe_convert(Ptr{Cvoid}, sock), -1, Int16(flag), Int16(0)),
                socks, flags
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

function poll(p::PollItems, timeout = -1)
    return poll(p.inner, p.sock, timeout)
end

function revents(p::PollItems)
    return map(item -> item.revents, p.inner)
end
