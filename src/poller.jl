# This is like a classic barrier, but instead of waking up the waiters when the
# barrier has been reached it will keep the waiters waiting until explicitly
# woken up by a coordinator. There may be multiple waiters, but there must be
# only 1 coordinator.
# It is also closable. When closed, waiter_wait() will not block.
mutable struct NotifiableBarrier
    const n::Int
    const waiter_condition::Threads.Condition
    const synced::Base.Event
    closed::Bool
    count::Int

    NotifiableBarrier(n::Int) = new(n, Threads.Condition(), Base.Event(true), false, 0)
end

# This should be called by a waiter
function waiter_wait(barrier::NotifiableBarrier)
    @lock barrier.waiter_condition begin
        if barrier.closed
            return
        end

        barrier.count += 1
        if barrier.count == barrier.n
            barrier.count = 0
            notify(barrier.synced)
        end

        wait(barrier.waiter_condition)
    end
end

# This should be called by the coordinator
coordinator_wait(barrier::NotifiableBarrier) = wait(barrier.synced)

Base.notify(barrier::NotifiableBarrier) = @lock barrier.waiter_condition notify(barrier.waiter_condition)

# Close the barrier and wake up any waiters and the coordinator
function Base.close(barrier::NotifiableBarrier)
    @lock barrier.waiter_condition begin
        if barrier.closed
            return
        end

        barrier.closed = true
        notify(barrier)
        notify(barrier.synced)
    end
end

# This should be called by a waiter when it dies so it doesn't cause the
# coordinator to hang.
function handle_waiter_exit(barrier::NotifiableBarrier)
    @lock barrier.waiter_condition begin
        barrier.count += 1
        if barrier.count == barrier.n
            notify(barrier)
            notify(barrier.synced)
        end
    end
end

struct PollItem
    socket::Socket
    readable::Bool
    writable::Bool
end

"""
    PollItem(socket::Socket; readable=true, writable=false)

This object can be passed to a [`Poller`](@ref) to indicate whether the poller
should wait for `socket` to become readable (`ZMQ_POLLIN`) or writable
(`ZMQ_POLLOUT`).
"""
PollItem(socket::Socket; readable=true, writable=false) = PollItem(socket, readable, writable)

"""
This object represents an event on a socket. It's returned by
[`wait(::Poller)`](@ref).

The fields are:
- `socket::Socket`
- `readable::Bool`
- `writable::Bool`
"""
struct PollResult
    socket::Socket
    readable::Bool
    writable::Bool
end

"""
A `Poller` can wait on multiple sockets simultaneously for them to be ready for
reading or writing.

# Examples
```julia
poller = Poller([sock1, sock2])
while true
    try
        result::PollResult = wait(poller; timeout=0.1)
        if ZMQ.recv(result.socket, String) == "exit"
            break
        end
    catch ex
        if !isa(ex, ZMQ.TimeoutError)
            rethrow()
        end
    end
end

close(poller)
```
"""
struct Poller
    items::Vector{PollItem}
    tasks::Vector{Task}
    wait_in_progress::Base.Event
    barrier::NotifiableBarrier
    channel::Channel{Union{PollResult, Symbol}}
end

function Base.show(io::IO, poller::Poller)
    sockets = join([repr(x.socket) for x in poller.items], ", ")
    close_str = isopen(poller.channel) ? "" : " (closed)"
    print(io, Poller, "([$sockets])", close_str)
end

Base.isopen(poller::Poller) = isopen(poller.channel)

# Long-running function to watch a socket.
function handle_pollitem(item::PollItem, poller::Poller)
    events = 0
    events |= item.readable ? lib.ZMQ_POLLIN : 0
    events |= item.writable ? lib.ZMQ_POLLOUT : 0

    c_pollitem = Ref(lib.zmq_pollitem_t(getfield(item.socket, :data),
                                        lib.zmq_fd_t(0),
                                        Cshort(events),
                                        Cshort(0)))
    barrier = poller.barrier

    try
        while isopen(poller.channel)
            # Wait to arm the poller. This is the 1st place the function may block.
            waiter_wait(poller.barrier)
            if !isopen(poller.channel)
                return
            end

            # Wait for the socket. This is the 2nd place the function may block.
            ret = lib.zmq_poll(c_pollitem, 1, 0)
            event = FDEvent(0)
            while ret == 0 && (event.events & WAKEUP) == 0
                event = wait(item.socket)
                ret = lib.zmq_poll(c_pollitem, 1, 0)
            end

            if ret == -1
                throw(StateError("Socket error when polling $(item.socket): " * jl_zmq_error_str()))
            end

            if (event.events & WAKEUP) == WAKEUP
                # If it was a dummy event from the poller then do nothing
                continue
            else
                # Otherwise tell the poller we have something
                readable = (c_pollitem[].revents & lib.ZMQ_POLLIN) == lib.ZMQ_POLLIN
                writable = (c_pollitem[].revents & lib.ZMQ_POLLOUT) == lib.ZMQ_POLLOUT
                result = PollResult(item.socket, readable, writable)
                put!(poller.channel, result)
            end
        end
    catch ex
        @error "Polling $(item.socket) failed." exception=(ex, catch_backtrace())
    finally
        handle_waiter_exit(barrier)
        close(poller.channel)
    end
end

"""
    Poller(items::Vector{PollItem})

Create a [`Poller`](@ref) from [`PollItem`](@ref)'s. This offers the most
flexibility since you can specify which events to monitor for each socket.
"""
function Poller(items::Vector{PollItem})
    # It's very important that we don't start the waiter tasks with a closed
    # socket. Otherwise the .socket field of the zmq_pollitem_t struct will be
    # null and zmq_poll() will fall back to polling the .fd field, which we
    # initialize to 0 so it will poll stdin.
    for item in items
        if !isopen(item.socket)
            throw(ArgumentError("Cannot poll a closed socket: $(item.socket)"))
        end
    end

    tasks = Task[]
    poller = Poller(items,
                    tasks,
                    Base.Event(),
                    NotifiableBarrier(length(items)),
                    # Allow an extra element for cancellation messages
                    Channel{Union{PollResult, Symbol}}(length(items) + 1))

    # We have one waiter task per item
    for item in items
        push!(tasks, Threads.@spawn handle_pollitem(item, poller))
    end

    # Wait for all the waiters to be ready for arming
    coordinator_wait(poller.barrier)

    # Signal the wait_in_progress Event since wait() has not been called yet
    notify(poller.wait_in_progress)

    return poller
end

"""
    Poller(sockets::Vector{Socket})

Create a [`Poller`](@ref) that monitors read events (`ZMQ_POLLIN`) for the given
sockets.
"""
Poller(sockets::Vector{Socket}) = Poller(map(PollItem, sockets))

"""
    Poller(f::Function, args)

Do-constructor that will call `f(poller)` and clean up the [`Poller`](@ref)
afterwards.
"""
function Poller(f::Function, args)
    p = Poller(args)
    try
        f(p)
    finally
        close(p)
    end
end

function cancel(poller::Poller, message::Symbol)
    put!(poller.channel, message)
end

"""
    wait(poller::Poller; timeout::Real=-1) -> PollResult

Wait for an event on one of the sockets monitored by `poller` and return a
[`PollResult`](@ref).

!!! danger
    This function is not threadsafe, you must not call it multiple times
    concurrently. It is also not threadsafe to use any of the sockets being
    monitored while the function is executing.

# Throws
- `ArgumentError`: if `poller` is closed.
- [`TimeoutError`](@ref): if a positive `timeout` is given and an event is not
  received in time.
- `ErrorException`: if the poller was closed while waiting.
"""
function Base.wait(poller::Poller; timeout::Real=-1)
    # Invariants:
    # - All the waiters must be synchronized at the barrier when the function is
    #   called.
    # - The function guarantees all the waiters will be at the barrier before the
    #   function returns.
    # - poller.wait_in_progress will be unsignalled while the function is operating on the
    #   poller sockets.

    while isready(poller.channel)
        x = take!(poller.channel)
        if !isa(x, Symbol)
            return x
        end
    end

    if !isopen(poller.channel)
        throw(ArgumentError("Poller is closed, cannot wait on it."))
    end

    # Reset to ensure that close(::Poller) will wait for this call to finish
    reset(poller.wait_in_progress)

    # Arm all the waiters
    notify(poller.barrier)

    timer = nothing
    if timeout > 0
        timer = Timer(timeout) do _
            cancel(poller, :zmq_jl_timeout)
        end
    end

    try
        poll_result::Union{PollResult, Symbol} = Symbol()
        try
            poll_result = take!(poller.channel)
        catch ex
            if ex isa InvalidStateException
                error("Poller was closed")
            else
                rethrow()
            end
        end

        if poll_result isa Symbol
            if poll_result == :zmq_jl_timeout
                throw(TimeoutError("Poll operation timed out.", timeout))
            else
                error("Poll operation was cancelled: $(poll_result)")
            end
        else
            return poll_result
        end
    finally
        if !isnothing(timer)
            close(timer)
        end

        # Disarm all the waiters and wait for them to synchronize so that there's no
        # chance of the socket being used by multiple threads.
        for item in poller.items
            if isopen(item.socket)
                notify(item.socket, WAKEUP)
            end
        end

        coordinator_wait(poller.barrier)

        # Clear any old WAKEUP events from the FDWatcher. Necessary because
        # FDWatcher is level-triggered and we don't want old WAKEUP events from
        # being incorrectly used the next time wait() is called.
        clear_wakeup_events(poller)

        notify(poller.wait_in_progress)
    end
end

function clear_wakeup_events(poller::Poller)
    for item in poller.items
        if isopen(item.socket)
            pollfd = getfield(item.socket, :pollfd)
            events = pollfd.watcher.events
            # if (events & WAKEUP) == WAKEUP
            #     @error "" item.socket, events exception=(ErrorException(""), backtrace())
            # end
            @lock pollfd.watcher.notify pollfd.watcher.events &= ~WAKEUP
        end
    end
end

"""
    close(poller::Poller)

Close a [`Poller`](@ref). It does not close the pollers sockets. This function
is threadsafe and can be called at any time.
"""
function Base.close(poller::Poller)
    # Close the channel and barrier so all waiters will exit
    close(poller.channel)
    close(poller.barrier)

    # Wakeup any waiters waiting on the socket
    for item in poller.items
        if isopen(item.socket)
            notify(item.socket, WAKEUP)
        end
    end

    # Wait for the waiters
    for t in poller.tasks
        wait(t)
    end

    clear_wakeup_events(poller)

    # Wait for any wait(::Poller) call to finish. This is necessary because
    # wait(::Poller) notifies the sockets and we want to ensure all of those
    # operations are done before returning so that the user can safely close the
    # sockets or whatever.
    wait(poller.wait_in_progress)
end
