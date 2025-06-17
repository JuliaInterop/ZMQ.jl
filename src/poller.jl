import Base.Threads: @spawn
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

struct ZMQResetPoll <: Exception end
struct ZMQStopPoll <: Exception end

struct PollItems2
    sockets::Vector{Socket}
    events::Vector{Int16}
    revents::Vector{Int16}
    _revents::Vector{Int16} # copy of revents to avoid race conditions with user code
    _tasks::Vector{Task}
    _channel::Channel{Int16}
    _trigger::Threads.Event
    _trigger_reset::Threads.Event
    _revents_lock::Vector{ReentrantLock}
    function PollItems2(
            socks::Vector{Socket},
            events::Vector{<:Integer},
        )
        channel = Channel{Int16}(length(socks) + 1)
        trigger = Threads.Event()
        trigger2 = Threads.Event()
        revents = zeros(Int16, length(socks))
        revents_lock = [ReentrantLock() for _ in eachindex(socks)]
        tasks = map(i -> @spawn(_polltask(trigger, trigger2, channel, socks[i], Int16(events[i]), revents, revents_lock[i], i)), eachindex(events))
        notify(trigger2)
        return new(socks, events, deepcopy(revents), revents, tasks, channel, trigger, trigger2, revents_lock)
    end
end

function _polltask(set_trigger::Threads.Event, reset_trigger::Threads.Event, c::Channel{T}, socket::Socket, event::Int16, revents::Vector{Int16}, revents_lock::ReentrantLock, index::Int) where {T}
    while true
        try
            # at any given poll there are three possible entrypoints:
            # either the task enters at #1: previous call it finished
            # in time or it's the first poll. If the previous call
            # didn't finish, it's still waiting on the socket #2. If
            # it did finish but not within the timeout, then it's at
            # #3.
            #1
            wait(set_trigger)
            while socket.events & event == 0
                #2
                wait(socket)
            end
            #3
            wait(set_trigger)
            lock(revents_lock)
            revents[index] = Int16(socket.events & event)
            result = count_ones(revents[index])
            unlock(revents_lock)
            put!(c, result)
            #4
            wait(reset_trigger)
            lock(revents_lock)
            revents[index] = Int16(0)
            unlock(revents_lock)
        catch e
            if e isa ZMQStopPoll
                break
            else
                rethrow(e)
            end
        end
    end
    return
end

function poll(p::PollItems2, timeout = -1)
    # cancel reset task
    reset(p._trigger_reset)
    # reset indicators
    fill!(p.revents, 0)
    # start all tasks
    notify(p._trigger)
    if timeout > 0 # either wait for timeout ms
        sleep(timeout * 1.0e-3)
        total = 0
    elseif timeout < 0 # or block indefinitely
        total = take!(p._channel)
    end # or don't block
    reset(p._trigger)
    # get amount of events
    while !isempty(p._channel)
        total += take!(p._channel)
    end
    # copy events to read array
    for i in eachindex(p._revents_lock)
        lock(p._revents_lock[i])
        p.revents[i] = p._revents[i]
        unlock(p._revents_lock[i])
    end
    notify(p._trigger_reset)
    return total
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
