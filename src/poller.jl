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

# Internal per-socket watcher. Each watcher blocks on the socket's own FDWatcher
# (via wait(socket)), which signals when the ZMQ_FD becomes readable. It never
# touches the zmq socket itself (zmq sockets aren't threadsafe) - the consumer is
# the sole reader of ZMQ_EVENTS - so it's safe to wait alongside the socket's
# owner.
mutable struct _Watcher
    const item::PollItem
    # Protected by the Poller's cond lock
    armed::Bool
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
mutable struct Poller
    const watchers::Vector{_Watcher}
    const tasks::Vector{Task}
    const cond::Threads.Condition
    @atomic closed::Bool
end

function Base.show(io::IO, poller::Poller)
    sockets = join([repr(w.item.socket) for w in poller.watchers], ", ")
    close_str = @atomic(poller.closed) ? " (closed)" : ""
    print(io, Poller, "([$sockets])", close_str)
end

Base.isopen(poller::Poller) = !@atomic(poller.closed)

function _watcher_loop(poller::Poller, w::_Watcher)
    cond = poller.cond

    try
        while true
            # Wait until the consumer arms us (or we're closed)
            @lock cond begin
                while !w.armed && isopen(poller)
                    wait(cond)
                end

                if !isopen(poller)
                    return
                end
            end

            # Wait on the socket's FDWatcher
            try
                wait(w.item.socket)
            catch ex
                if ex isa EOFError
                    # The socket and its FDWatcher was closed
                    return
                else
                    rethrow()
                end
            end

            # Wake the consumer and disarm ourselves
            @lock cond begin
                if !isopen(poller)
                    return
                end

                w.armed = false
                notify(cond)
            end
        end
    finally
        @lock cond notify(cond)
    end
end

"""
    Poller(items::Vector{PollItem})

Create a [`Poller`](@ref) from [`PollItem`](@ref)'s. This offers the most
flexibility since you can specify which events to monitor for each socket.
"""
function Poller(items::Vector{PollItem})
    for item in items
        if !isopen(item.socket)
            throw(ArgumentError("Cannot poll a closed socket: $(item.socket)"))
        end
    end

    watchers = [_Watcher(item, false) for item in items]
    poller = Poller(watchers, Task[], Threads.Condition(), false)

    for w in watchers
        push!(poller.tasks, Threads.@spawn _watcher_loop(poller, w))
    end

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

# Read ZMQ_EVENTS for a watcher's socket and return the (readable, writable)
# readiness masked to what the PollItem actually requested. Reading ZMQ_EVENTS
# also resets the edge-triggered ZMQ_FD, which is what lets the watchers block
# without spinning.
function _readiness(w::_Watcher)
    events = w.item.socket.events
    readable = w.item.readable && (events & lib.ZMQ_POLLIN) != 0
    writable = w.item.writable && (events & lib.ZMQ_POLLOUT) != 0
    return readable, writable
end

"""
    wait(poller::Poller; timeout::Real=-1) -> PollResult

Wait for an event on one of the sockets monitored by `poller` and return a
[`PollResult`](@ref).

!!! danger
    It is not threadsafe to use any of the sockets being monitored while the
    function is executing.

# Throws
- `ArgumentError`: if `poller` is closed.
- [`TimeoutError`](@ref): if a positive `timeout` is given and an event is not
  received in time.
- `ErrorException`: if the poller was closed while waiting.
- `StateError`: if a monitored socket errored.
"""
function Base.wait(poller::Poller; timeout::Real=-1)
    cond = poller.cond

    timer = nothing
    timed_out = Ref(false)

    @lock cond begin
        if !isopen(poller)
            throw(ArgumentError("Poller is closed, cannot wait on it."))
        end

        if timeout > 0
            timer = Timer(timeout) do _
                @lock cond begin
                    timed_out[] = true
                    notify(cond)
                end
            end
        end

        try
            while true
                if !isopen(poller)
                    error("Poller was closed")
                end

                # Check the socket statuses
                for w in poller.watchers
                    readable, writable = _readiness(w)

                    if readable || writable
                        return PollResult(w.item.socket, readable, writable)
                    end
                end

                if timed_out[]
                    throw(TimeoutError("Poll operation timed out.", timeout))
                end

                # If none are ready, arm the watchers and block until one of them
                # fires, or the timeout elapses, or the poller is closed.
                for w in poller.watchers
                    w.armed = true
                end
                notify(cond)
                wait(cond)
            end
        finally
            if !isnothing(timer)
                close(timer)
            end
        end
    end
end

"""
    close(poller::Poller)

Close a [`Poller`](@ref). It does not close the pollers sockets. This function
is threadsafe and can be called at any time.
"""
function Base.close(poller::Poller)
    @lock poller.cond begin
        if !isopen(poller)
            return
        end

        @atomic poller.closed = true
        # Wake the consumer and any parked watchers
        notify(poller.cond)
    end

    # Wake any watcher blocked in wait(socket) so it sees the poller is closed
    # and exits. A single notify can be lost: another task waiting on the same
    # FDWatcher (e.g. one blocked in recv()) may consume it before a watcher
    # that hasn't quite reached wait(socket) yet, so keep re-notifying until
    # the watcher task exits.
    timed_out_sockets = Socket[]
    for (w, t) in zip(poller.watchers, poller.tasks)
        for _ in 1:10
            if istaskdone(t)
                break
            end

            try
                notify(w.item.socket)
            catch ex
                if !(ex isa ArgumentError)
                    rethrow()
                end

                # The socket was closed concurrently; its FDWatcher closing
                # will wake the watcher instead.
            end

            sleep(0.001)
        end

        if !istaskdone(t)
            push!(timed_out_sockets, w.item.socket)
        end
    end

    if !isempty(timed_out_sockets)
        error("Timed out waiting for the watchers of these sockets to exit: $(timed_out_sockets)")
    end

    # Wait for the watcher tasks to exit
    for t in poller.tasks
        wait(t)
    end
end
