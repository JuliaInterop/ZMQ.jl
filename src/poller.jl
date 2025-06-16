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

struct PollItems2
    sockets::Vector{Socket}
    events::Vector{Int16}
    revents::Vector{Int16}
    _revents::Vector{Int16} # copy of revents to avoid race conditions with user code
    _tasks::Vector{Task}
    _sleeptask::Task
    _sleepchannel::Channel
    _channel::Channel
    _trigger::Threads.Event
    _trigger_reset::Threads.Event
    function PollItems2(
        socks::Vector{Socket},
        events::Vector{<:Integer},
        )
        channel = Channel{Int16}(length(socks)+1)
        sleepchannel = Channel{Float64}(1)
        trigger = Threads.Event()
        trigger2 = Threads.Event()
        revents = zeros(Int16, length(socks))
        tasks = Task[]
        for i = eachindex(events)
            push!(tasks, @spawn _polltask(socks[i], Int16(events[i]), revents, i, trigger, trigger2, channel))
        end
        sleeptask = @spawn begin
            while true
                try
                    wait(trigger)
                    t = take!(sleepchannel)
                    sleep(t)
                    put!(channel, 0)
                catch e
                    if e isa ZMQResetPoll
                        wait(trigger2)
                        put!(channel, 0)
                        continue
                    else
                        rethrow(e)
                    end
                end
            end
        end
        new(socks, events, deepcopy(revents), revents, tasks, sleeptask, sleepchannel, channel, trigger, trigger2)
    end
end

function _polltask(socket::Socket, event::Int16, revents::Vector{Int16}, index::Int, trigger::Threads.Event, trigger2::Threads.Event, channel::Channel)
    while true
        try 
            wait(trigger)
            while socket.events & event == 0
                wait(socket)
            end
            revents[index] = Int16(socket.events & event)
            put!(channel, count_ones(revents[index]))
            wait(trigger2)
        catch e
            if e isa ZMQResetPoll
                wait(trigger2)
                put!(channel, 0)
                continue
            else
                rethrow(e)
            end
        end
    end
end

struct ZMQResetPoll <: Exception end
struct ZMQStopPoll <: Exception end

function poll(p::PollItems2, timeout=-1)
    # reset indicators
    fill!(p.revents, 0)
    fill!(p._revents, 0)
    # set timeout
    if timeout > 0
        put!(p._sleepchannel, timeout * 1e-3)
    end
    # start all tasks
    notify(p._trigger)
    # wait until one finishes
    fetch(p._channel)
    reset(p._trigger)
    # reset all the rest
    for task in p._tasks
        schedule(task, ZMQResetPoll(), error=true)
    end
    schedule(p._sleeptask, ZMQResetPoll(), error=true)
    # get amount of events
    total = 0
    while !isempty(p._channel)
        total += take!(p._channel)
    end
    # copy events to read array
    copy!(p.revents, p._revents)
    notify(p._trigger_reset)
    for _ = 1:(length(p.revents) + 1)
        take!(p._channel)
    end
    reset(p._trigger_reset)
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
