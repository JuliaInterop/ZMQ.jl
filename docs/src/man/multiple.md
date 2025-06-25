# Multiple Sockets
Many ZMQ applications use multiple sockets.
Unfortunately, integrating the ZMQ with the Julia task scheduler can be tricky and the optimal way to write a program with multiple sockets depends on your use case.
In general there are two use cases to distinguish: 

1. An application forwards messages between multiple sockets that do not expect replies (like in PUSH/PULL), or it listens on multiple sockets but does not forward messages between them. A typical example is a worker that may not only receives tasks/sends results via PULL and PUSH sockets, but also listens for a broadcast signal on a SUB socket. Another example is an application that monitors a heartbeat on socket 1 and sends data over socket 2.
2. An application forwards messages between multiple sockets which expect replies. A typical use case is a broker forwarding messages between clients and workers.

In case 1, it is advisable to spawn a task for each socket and communicate internally using Julia async tools.
In case 2, a poller is your best option.
The next tutorials illustrate this.

## Handling multiple receive-only and/or send-only sockets
This tutorial illustrates two approaches to program a basic message poller, inspired by the example in the [ZMQ guide](https://zguide.zeromq.org/docs/chapter2/#Handling-Multiple-Sockets).
Suppose an application wants to read from a weather forecast service which uses a ZMQ PUB socket and simultaneously acts as a worker for a task ventilator, which publishes its tasks over a ZMQ PUSH socket.
To allow the program to exit cleanly, we additionally add a kill socket that shuts down the application.
As such, the application has in total three sockets to read from: a SUB socket for the weather updates, a PULL socket for the tasks and a SUB socket for the killswitch.
None of these sockets can send back messages.

The code below implements the task ventilator, weather server and kill service.
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
    sender = Socket(ctx, PUB)
    bind(sender, kill_addr)
    send(sender, "")
    return
end
```
!!! note
	We could have just as easily created a single ZMQ context and passed it to all functions as an argument, but in this example the approaches with a shared or with individual contexts are equivalent.

### ZMQ Poller
Arguably the easiest way to implement the application is by using a ZMQ poller.
Simply connect each socket and create a `PollItems` object like below.
The poller integrates with the Julia task system, and as such can be used in combination with regular Julia tasks.
```julia
function main_poller()
    ctx = Context()

    receiver = Socket(ctx, PULL)
    connect(receiver, ventilator_addr)

    subscriber = Socket(ctx, SUB)
    connect(subscriber, weather_addr)
    subscribe(subscriber, "")

    killer = Socket(ctx, SUB)
    connect(killer, kill_addr)
    subscribe(killer, "")

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

To run this example.
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

While this program looks simple and clean, the poller has some drawbacks with respect to performance.
The poller internally uses `@async` to schedule tasks that listen to each socket which makes the poll task a sticky task, meaning the `tmain` task cannot migrate across Julia threads.
If the same thread is occupied by both the poller and another task, then the poller cannot receive messages while that other task is running.
For this reason, it is preferable to use plain Julia tasks like below.
Alternatively one can manually manage threads using [Threadpools.jl](https://github.com/tro3/ThreadPools.jl) or similar tools to avoid this problem.

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
        killer = Socket(ctx, SUB)
        connect(killer, kill_addr)
        subscribe(killer, "")
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

To run the program.
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
This approach is a bit more verbose than the ZMQ poller, but from a technical perspective it is the superior option.

## Receiving and sending on multiple sockets
Above example was relatively simple because the application does not need to respond when it receives a message.
In this example we'll implement a broker that receives a message, forwards it to a worker and then replies to the client it received the message from.
Clients use a simple REQ socket to send a number to the broker.
The broker uses a ROUTER socket to receive requests from clients and uses a DEALER socket to talk to the worker.
Workers use a REP socket to receive tasks and reply back.
Additionally, we'll use a kill signal to stop the broker and workers.

### Clients
```julia
const broker_frontend = "tcp://localhost:5560"
const broker_backend = "tcp://localhost:5561"

function client(i)
    ctx = Context()
    sock = Socket(ctx, REQ)
    connect(sock, broker_frontend)
    for j in 1:i
        println("Client $i sends $j")
        send(sock, "$j")
        k = recv(sock, String)
        println("Client $i got $k")
    end
    close(sock)
    return
end
```

### Worker
The worker implementation could be done with a poller or with regular Julia tasks.
Both are valid approaches, and what to do depends on personal preference.
In a scenario where each worker is pinned to its own thread, the worker with poller would not be a bad implementation.
```julia
function worker(i)
    ctx = Context()
    sock = Socket(ctx, REP)
    connect(sock, broker_backend)
    killsock = Socket(ctx, SUB)
    connect(killsock, kill_addr)
    subscribe(killsock, "")
    poller = PollItems([sock, killsock], [ZMQ.POLLIN, ZMQ.POLLIN])
    println("Worker online")
    while true
        poll(poller)
        poller.revents[2] & ZMQ.POLLIN != 0 && break
        if poller.revents[1] & ZMQ.POLLIN != 0
            j = parse(Int, recv(sock, String))
            println("Worker $i got $j")
            k = j^2
            println("Worker $i replies $k")
            send(sock, "$k")
        end
    end
    close(poller)
    return
end

function worker_with_tasks(i)
    ctx = Context()
    t1 = @spawn begin
        sock = Socket(ctx, REP)
        connect(sock, broker_backend)
        while true
            j = parse(Int, recv(sock, String))
            println("Worker $i got $j")
            k = j^2
            println("Worker $i replies $k")
            send(sock, "$k")
        end
    end
    t2 = @spawn begin
        killsock = Socket(ctx, SUB)
        connect(killsock, kill_addr)
        subscribe(killsock, "")
        recv(killsock)
    end
    wait(t2)
    schedule(t1, InterruptException(), error = true)
    return
end
```

### Poller-based broker
The broker is implemented with a poller.
In this case there is a fundamental need to receive messages from both sockets and forward them to the other, which cannot be easily achieved with Julia tasks.
```julia
function broker()
    ctx = Context()
    frontend = Socket(ctx, ROUTER)
    bind(frontend, broker_frontend)

    backend = Socket(ctx, DEALER)
    bind(backend, broker_backend)

    killer = Socket(ctx, SUB)
    connect(killer, kill_addr)
    subscribe(killer, "")

    poller = PollItems(
        [frontend, backend, killer],
        [ZMQ.POLLIN, ZMQ.POLLIN, ZMQ.POLLIN]
    )
    println("Broker online")
    while true
        poll(poller)
        poller.revents[3] & ZMQ.POLLIN != 0 && break
        # backend -> frontend
        if poller.revents[2] & ZMQ.POLLIN != 0
            msg = recv_multipart(backend)
            for i in eachindex(msg)
                send(frontend, msg[i], more = i != lastindex(msg))
            end
        end
        # frontend -> backend
        if poller.revents[1] & ZMQ.POLLIN != 0
            msg = recv_multipart(frontend)
            for i in eachindex(msg)
                more = i != lastindex(msg)
                send(backend, msg[i]; more)
            end
        end
    end

    close(poller)
    println("Finishing")
    return
end
```

To run the example.
```julia
broker_task = @spawn broker()
worker_tasks = vcat(map(i -> @spawn(worker(i)), 1:2), map(i -> @spawn(worker_with_tasks(i)), 3:4))
client_tasks = map(i -> @spawn(client(i)), 1:3)

foreach(wait, client_tasks)
killmain()
foreach(wait, worker_tasks)
wait(broker_task)
```

### Why no task-based broker?
A naive implementation of the broker above could be implemented like below.
This is **incorrect** and should **never** be done.
ZMQ sockets are not thread-safe, and doing this may result in a deadlock or a crash of the application.
Even if the `@spawn` calls were replaced by `@async` the order of send/recv calls is not known and deadlocks could occur.
```julia
function broken_broker()
    ctx = Context()

    frontend = Socket(ctx, ROUTER)
    bind(frontend, broker_frontend)

    backend = Socket(ctx, DEALER)
    bind(backend, broker_backend)

    killer = Socket(ctx, SUB)
    connect(killer, kill_addr)
    subscribe(killer, "")

    t1 = @spawn begin
        while true
            msg = recv_multipart(frontend)
            for i in eachindex(msg)
                more = i != lastindex(msg)
                send(backend, msg[i]; more)
            end
        end
    end
    t2 = @spawn begin
        while true
            msg = recv_multipart(backend)
            for i in eachindex(msg)
                more = i != lastindex(msg)
                send(frontend, msg[i]; more)
            end
        end
    end
    t3 = @spawn begin
        recv(killer)
    end
    wait(t3)
    schedule(t1, InterruptException(), error = true)
    schedule(t2, InterruptException(), error = true)
    return
end
```

The application will not have the expected behaviour. Try to run it with below snippet.
```julia
broker_task = @spawn broken_broker()
worker_tasks = vcat(map(i -> @spawn(worker(i)), 1:2), map(i -> @spawn(worker_with_tasks(i)), 3:4))
client_tasks = map(i -> @spawn(client(i)), 1:3)

foreach(wait, client_tasks)
killmain()
foreach(wait, worker_tasks)
wait(broker_task)
```
