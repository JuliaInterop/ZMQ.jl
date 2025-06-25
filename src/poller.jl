struct ZMQStopPoll <: Exception end
struct ZMQResetPoll <: Exception end

"""
    PollItems(socks::Vector{Socket}, events::Vector{<:Integer})
Create a PollItems object to poll multiple sockets
simultaneously. `socks` is the vector of sockets to poll. `events`
represents ZMQ events to poll for. Valid values for `events` entries
are `ZMQ.POLLIN`, `ZMQ.POLLOUT` and `ZMQ.POLLIN | ZMQ.POLLOUT`.

This object creates a poller and starts the necessary background tasks.
To actually poll the sockets, use [`poll`](@ref).
The poll result is written to the `revents` field of the `PollItems` struct.

When the poller is no longer needed, it is recommended to call `close(items::PollItems)`.

!!! warning
    This spawns tasks using `@async`, meaning that the task that
    instantiates the PollItems object will become sticky. For more
    info refer to [the @async documentation](https://docs.julialang.org/en/v1/base/parallel/#Base.@async).
"""
struct PollItems
    sockets::Vector{Socket}
    events::Vector{Int16}
    revents::Vector{Int16}
    _eventnotify::Channel{Bool}
    _trigger::Threads.Condition
    _ctimeout::Channel{Float64}
    _handshake::Threads.Condition
    _tasks::Vector{Task}
    _isclosed::Ref{Bool}
    function PollItems(socks::Vector{Socket}, events::Vector{<:Integer})
        @assert length(socks) == length(events)
        eventnotify = Channel{Bool}()
        trigger = Threads.Condition()
        ctimeout = Channel{Float64}(1)
        handshake = Threads.Condition()
        timertask = @async while true
            try
                # receive timeout from poller
                t = take!(ctimeout)
                # notify poller that it has accepted
                lock(() -> notify(handshake), handshake)
                # wait until poller issues start
                lock(() -> wait(trigger), trigger)
                sleep(t)
                put!(eventnotify, false)
            catch e
                e isa ZMQStopPoll && break
                e isa ZMQResetPoll && continue
                rethrow(e)
            end
        end
        workertasks = map(zip(socks, events)) do (sock, event)
            @async while isopen(sock)
                try
                    lock(() -> wait(trigger), trigger)
                    while sock.events & event == 0
                        wait(sock)
                    end
                    put!(eventnotify, true)
                catch e
                    # stop poll || socket closed
                    (e isa ZMQStopPoll || e isa EOFError) && break
                    if e isa ZMQResetPoll
                        lock(() -> notify(handshake), handshake)
                        continue
                    end
                    rethrow(e)
                end
            end
        end
        tasks = vcat(workertasks, timertask)
        foreach(errormonitor, tasks)
        errormonitor(timertask)
        revents = zeros(Int16, length(socks))
        return new(socks, Int16.(events), revents, eventnotify, trigger, ctimeout, handshake, tasks, Ref(false))
    end
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
"""
function poll(p::PollItems, timeout = -1)
    p._isclosed[] && throw(StateError("Poller is closed"))
    p.revents .= Int16(0)
    if timeout > 0
        # putting does not yield so wait until timer indicates readiness
        # otherwise timer does not catch the trigger
        put!(p._ctimeout, timeout * 1.0e-3) # convert ms to s
        lock(() -> wait(p._handshake), p._handshake)
    end
    if timeout != 0
        lock(() -> notify(p._trigger), p._trigger)
        events_happened = take!(p._eventnotify)
        foreach(p._tasks) do task
            schedule(task, ZMQResetPoll(), error = true)
        end
        # must yield for tasks to intercept the reset correctly
        lock(() -> wait(p._handshake), p._handshake)
        events_happened || return 0
    end
    total = 0
    for i in eachindex(p.sockets)
        p.revents[i] = p.sockets[i].events & p.events[i]
        p.revents[i] == 0 || (total += 1;)
    end
    return total
end

function Base.close(poller::PollItems)
    for task in poller._tasks
        istaskdone(task) || schedule(task, ZMQStopPoll(), error = true)
        wait(task)
    end
    poller._isclosed[] = true
    return
end
