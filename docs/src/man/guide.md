# Guide

## Usage

```julia
using ZMQ

s1=Socket(REP)
s2=Socket(REQ)

bind(s1, "tcp://*:5555")
connect(s2, "tcp://localhost:5555")

send(s2, "test request")
msg = recv(s1, String)
send(s1, "test response")
close(s1)
close(s2)
```

The `send(socket, x)` and `recv(socket, SomeType)` functions make an extra copy of the data when converting
between ZMQ and Julia.   Alternatively, for large data sets (e.g. very large arrays or long strings), it can
be preferable to share data, with `send(socket, Message(x))` and `msg = recv(Message)`, where the `msg::Message`
object acts like an array of bytes; this involves some overhead so it may not be optimal for short messages.

(Help in writing more detailed documentation would be welcome!)

## Multiple Sockets
Many ZMQ applications use multiple sockets.
Unfortunately, integrating the ZMQ with the Julia task scheduler can be tricky and there currently is not one optimal way to use multiple sockets.
Therefore it's good to know which options exist.
This tutorial illustrates two approaches to program a basic message poller, inspired by the example in the [ZMQ guide](https://zguide.zeromq.org/docs/chapter2/#Handling-Multiple-Sockets).

### Common functions
To simulate multiple streams, we use the example in the [ZMQ guide](https://zguide.zeromq.org/docs/chapter2/#Handling-Multiple-Sockets) where a client wants to read from a weather forecast service which uses a ZMQ PUB socket and simultaneously acts as a worker for a task ventilator, which publishes its tasks over a ZMQ PUSH socket.
To allow the program to exit cleanly, we additionally add a kill socket that shuts down the client.

The code below implements the task ventilator, weather server and kill service. 
Note that we could have just as easily created a single ZMQ context and passed it to all functions as an argument, but in this example the approach with a shared or with individual contexts are equivalent.
```julia
using ZMQ

const kill_addr = "tcp://localhost:5558"
const ventilator_addr = "tcp://localhost:5557"
const weather_addr = "tcp://localhost:5556"

function ventilator()
    ctx = Context()
    sender = Socket(ctx, PUSH)
    bind(sender, ventilator_addr)
    for i in 1:5
        sleep(rand() * 3)
        send(sender, string(i))
    end
    return
end

function weatherserver()
    # allow the main to come online first
    # to avoid dropped messages.
    # this is not reliable but it suffices
    # for this tutorial
    sleep(1)
    ctx = Context()
    sender = Socket(ctx, PUB)
    bind(sender, weather_addr)
    for i in 1:5
        sleep(rand() * 3)
        send(sender, string(i))
    end
    return
end

function killmain()
    ctx = Context()
    sender = Socket(ctx, PUSH)
    bind(sender, kill_addr)
    send(sender, "")
    return
end
```

### ZMQ Poller
The ZMQ poller allows to read from multiple sockets simultaneously.
Its interface mimics that of the ZMQ implementation.
It integrates with the Julia task system, and as such can be used in combination with regular Julia tasks.
```julia
function main_poller()
    ctx = Context()

    receiver = Socket(ctx, PULL)
    connect(receiver, ventilator_addr)

    subscriber = Socket(ctx, SUB)
    connect(subscriber, weather_addr)
    subscribe(subscriber, "")

    killer = Socket(ctx, PULL)
    connect(killer, kill_addr)

    items = PollItems([receiver, subscriber, killer], [ZMQ.POLLIN, ZMQ.POLLIN, ZMQ.POLLIN])

    while true
        poll(items)
        if items.revents[1] & ZMQ.POLLIN != 0
            msg = recv(receiver, String)
            sleep(rand())
            println("Received task $msg")
        end
        if items.revents[2] & ZMQ.POLLIN != 0
            msg = recv(subscriber, String)
            sleep(rand())
            println("Received subscription $msg")
        end
        if items.revents[3] & ZMQ.POLLIN != 0
            println("Received kill signal")
            break
        end
    end
    return
end
```

To run it.
```julia
import Base.Threads: @spawn

tvent = @spawn ventilator()
tweath = @spawn weatherserver()
tmain = @spawn main_poller()

wait(tvent)
wait(tweath)
killmain()
wait(tmain)
```

The poller internally uses `@async` to schedule tasks that listen to each socket which makes the poll task a sticky task.
This can have performance impacts on your code: the `tmain` task cannot migrate across Julia threads.
Consider the implications of this. 
If both the poller and another task run on the same thread, then the poller cannot receive messages while the other task is running.
Possible mitigation measures are to manually manage threads using [Threadpools.jl](https://github.com/tro3/ThreadPools.jl) or similar tools.
For many applications, this won't be a significant problem, but it should be kept in mind.

### Use Julia Tasks

Instead of polling multiple sockets in a single task, it's possible to start one task per socket that you want to listen on like below (in fact, this closely resembles how the poller works internally).
In this example we use a [channel](https://docs.julialang.org/en/v1/base/parallel/#Channels) to communicate the data to a single worker loop.
```julia
function main_tasks()
    ctx = Context()
    c = Channel{Tuple{String, String}}()

    t1 = @spawn begin
        receiver = Socket(ctx, PULL)
        connect(receiver, ventilator_addr)
        while true
            msg = recv(receiver, String)
            put!(c, ("ventilator", msg))
        end
    end

    t2 = @spawn begin
        subscriber = Socket(ctx, SUB)
        connect(subscriber, weather_addr)
        subscribe(subscriber, "")
        while true
            msg = recv(subscriber, String)
            put!(c, ("weather", msg))
        end
    end

    t3 = @spawn begin
        killer = Socket(ctx, PULL)
        connect(killer, kill_addr)
        while true
            msg = recv(killer, String)
            put!(c, ("kill", msg))
        end
    end

    workerloop = @spawn while true
        source, msg = take!(c)
        if source == "ventilator"
            sleep(rand())
            println("Received task $msg")
        elseif source == "weather"
            sleep(rand())
            println("Received subscription $msg")
        elseif source == "kill"
            sleep(rand())
            println("Received kill signal")
            break
        end
    end
	
    wait(workerloop)

    for t in (t1, t2, t3)
        schedule(t, InterruptException, error = true)
    end

    return
end
```

To run it
```julia
import Base.Threads: @spawn

tvent = @spawn ventilator()
tweath = @spawn weatherserver()
tmain = @spawn main_tasks()

wait(tvent)
wait(tweath)
killmain()
wait(tmain)
```

Contrary to the approach with poller, all tasks are able to migrate across Julia threads, so there is no associated performance penalty.
However, depending on your use case and personal preference, this may not be the most ergonomic solution.
