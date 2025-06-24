struct ZMQStopPoll <: Exception end

"""
    PollItems(socks::Vector{Socket}, events::Vector{<:Integer})
Create a PollItems object to poll multiple sockets
simultaneously. `socks` is the vector of sockets to poll. `events`
represents ZMQ events to poll for. Valid values for `events` entries
are `ZMQ.POLLIN`, `ZMQ.POLLOUT` and `ZMQ.POLLIN | ZMQ.POLLOUT`.

This object creates a poller and starts the necessary background tasks.
To actually poll the sockets, use [`poll`](@ref).
The poll result is written to the `revents` field of the `PollItems` struct.

!!! warning
    This spawns tasks using `@async`, meaning that the task that
    instantiates the PollItems object will become sticky. For more
    info refer to [the @async documentation](https://docs.julialang.org/en/v1/base/parallel/#Base.@async).
"""
struct PollItems
    sockets::Vector{Socket}
    events::Vector{Int16}
    revents::Vector{Int16}
    _revents::Vector{Int16} # copy of revents to avoid race conditions with user code
    _tasks::Vector{Task}
    _channel::Channel{Int16}
    _trigger::Threads.Event
    _trigger_reset::Threads.Event
    _revents_lock::Vector{ReentrantLock}
    function PollItems(socks::Vector{Socket}, events::Vector{<:Integer})
        channel = Channel{Int16}(length(socks) + 1)
        trigger = Threads.Event()
        trigger2 = Threads.Event()
        revents = zeros(Int16, length(socks))
        revents_lock = [ReentrantLock() for _ in eachindex(socks)]
        # All listening tasks must run on a single thread
        tasks = map(i -> @async(_polltask(trigger, trigger2, channel, socks[i], Int16(events[i]), revents, revents_lock[i], i)), eachindex(events))
        notify(trigger2)
        return new(socks, events, deepcopy(revents), revents, tasks, channel, trigger, trigger2, revents_lock)
    end
end

function _polltask(set_trigger::Threads.Event, reset_trigger::Threads.Event, c::Channel{T}, socket::Socket, event::Int16, revents::Vector{Int16}, revents_lock::ReentrantLock, index::Int) where {T}
    while true
        try
            # at any given poll there are three possible entrypoints:
            # either the task enters at #1: previous call finished
            # in time or it's the first poll. If the previous call
            # didn't finish, it's still waiting on the socket #2. If
            # it did finish but not within the timeout, then it's at
            # #3.
            #1
            wait(set_trigger)
            while socket.events & event == 0
                #2
                wait(socket)
                socket.events & event != 0 && #= #3 =# wait(set_trigger)
            end
            lock(revents_lock)
            revents[index] = Int16(socket.events & event)
            result = count_ones(revents[index])
            unlock(revents_lock)
            put!(c, result)
            #4 wait until ready to poll again
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

"""
    poll(p::PollItems, timeout = -1)
Poll the PollItems for events. If no timeout is provided, this blocks
until an event occurs. Otherwise it sleeps for `timeout` miliseconds
and returns the amount of sockets for which an event occured.

# Note on event indicators and the poller
The poller returns the amount of sockets for which events
occured. This is not the same as the amount of messages which can be
received/sent. The following scenarios are valid:
- Socket 1 receives 1 message, the poller returns 1
- Socket 1 receives 10 messages, the poller returns 1
- Socket 1 receives 10 messages and socket 2 receives 1 message, the
  poller returns 2
- Socket 1 receives 10 messages and socket 2 receives 10 messages, the
  poller returns 2
After polling socket input, the user should read from the socket until
no more messages are available like so:
```julia
p = PollItems([socket1, socket2], [ZMQ.POLLIN, ZMQ.POLLIN])
poll(p, 100)
for i = eachindex(p.revents)
    if p.revents[i] & ZMQ.POLLIN != 0
       while p.sockets[i].events & ZMQ.POLLIN != 0
             data = recv(p.sockets[i])
             dostuff(data)
        end
    end
end
```
"""
function poll(p::PollItems, timeout = -1)
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
