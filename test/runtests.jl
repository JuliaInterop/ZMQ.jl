import Base.Threads: @spawn
import Aqua
using ZMQ, Test

@info("Testing with ZMQ version $(ZMQ.version)")

@testset "ZMQ contexts" begin
    ctx = Context()
    @test ctx isa Context
    @test propertynames(ctx) isa Tuple

    @test_logs (:warn, r"set(.+) is deprecated") ZMQ.set(ctx, ZMQ.IO_THREADS, 3)
    @test (@test_logs (:warn, r"get(.+) is deprecated") get(ctx, ZMQ.IO_THREADS)) == 3

    @test (ctx.io_threads = 2) == 2
    @test ctx.io_threads == 2
    ZMQ.close(ctx)

    @test_throws StateError ctx.io_threads = 1
    @test_throws StateError ctx.io_threads

    #try to create socket with expired context
    @test_throws StateError Socket(ctx, PUB)

    # Smoke tests for Base.show()
    ctx = Context()
    @test repr(ctx) == "Context(WeakRef[])"
    close(ctx)
    @test repr(ctx) == "Context() (closed)"
end

# This test is in its own function to keep it simple and try to trick Julia into
# thinking it can safely GC the Context.
function context_gc_test()
    ctx = Context()
    s = Socket(ctx, PUB)

    # Force garbage collection to attempt to delete ctx
    GC.gc()

    # But it shouldn't be garbage collected since the socket should have a
    # reference to it, so the socket should still be open.
    return @test isopen(s)
end

@testset "ZMQ sockets" begin
    context_gc_test()

    s = Socket(PUB)
    @test s isa Socket
    ZMQ.close(s)

    s1 = Socket(REP)
    s1.sndhwm = 1000
    s1.linger = 1
    s1.routing_id = "abcd"

    @test s1.routing_id == "abcd"
    @test s1.sndhwm === 1000
    @test s1.linger === 1
    @test s1.rcvmore === false

    s2 = Socket(REQ)
    @test s1.type == REP
    @test s2.type == REQ

    ZMQ.bind(s1, "tcp://*:5555")
    ZMQ.connect(s2, "tcp://localhost:5555")

    msg = Message("test request")

    # Smoke tests
    @test Base.elsize(msg) == 1
    @test Base.strides(msg) == (1,)

    # Test similar() and copy() fixes in https://github.com/JuliaInterop/ZMQ.jl/pull/165
    @test similar(msg, UInt8, 12) isa Vector{UInt8}
    @test copy(msg) == codeunits("test request")

    ZMQ.send(s2, Message("test request"))
    @test unsafe_string(ZMQ.recv(s1)) == "test request"
    ZMQ.send(s1, Message("test response"))
    @test unsafe_string(ZMQ.recv(s2)) == "test response"

    ZMQ.send(s2, "test request 2")
    @test ZMQ.recv(s1, String) == "test request 2"
    ZMQ.send(s1, Vector(codeunits("test response 2")))
    @test String(ZMQ.recv(s2, Vector{UInt8})) == "test response 2"
    ZMQ.send(s2, 3.14159)
    @test ZMQ.recv(s1, Float64) === 3.14159
    ZMQ.send(s1, [314159, 12345])
    @test ZMQ.recv(s2, Vector{Int}) == [314159, 12345]

    # Test task-blocking behavior
    c = Base.Condition()
    global msg_sent = false
    @async begin
        global msg_sent
        sleep(0.5)
        msg_sent = true
        ZMQ.send(s2, Message("test request"))
        @test (unsafe_string(ZMQ.recv(s2)) == "test response")
        notify(c)
    end

    # This will hang forver if ZMQ blocks the entire process since
    # we'll never switch to the other task
    @test unsafe_string(ZMQ.recv(s1)) == "test request"
    @test msg_sent == true
    ZMQ.send(s1, Message("test response"))
    wait(c)

    # Test _Message task-blocking behavior, similar to above
    c = Base.Condition()
    msg_sent = false
    @async begin
        global msg_sent
        sleep(0.5)
        msg_sent = true
        ZMQ.send(s2, "another test request")
        @test ZMQ.recv(s2, String) == "another test response"
        notify(c)
    end
    @test ZMQ.recv(s1, String) == "another test request"
    @test msg_sent == true
    ZMQ.send(s1, "another test response")
    wait(c)

    ZMQ.send(s2, Message("another test request"))
    msg = ZMQ.recv(s1)
    o = IOBuffer(msg)
    @test String(take!(o)) == "another test request"
    ZMQ.send(s1) do io
        print(io, "buffer ")
        print(io, "this")
    end
    @test String(take!(ZMQ.recv(s2, IOBuffer))) == "buffer this"

    @testset "Message AbstractVector interface" begin
        m = Message("1")
        @test m[1] == 0x31
        @test (m[1] = 0x32) === 0x32
        @test unsafe_string(m) == "2"
        finalize(m)
    end

    # Test multipart messages
    data = ["foo", "bar", "baz"]
    ZMQ.send_multipart(s2, data)

    # Test receiving Message's
    msgs = ZMQ.recv_multipart(s1)
    @test msgs isa Vector{Message}
    @test String.(msgs) == data

    # Test receiving a specific type
    data = Int[1, 2, 3]
    ZMQ.send_multipart(s1, data)
    msgs = ZMQ.recv_multipart(s2, Int)
    @test msgs isa Vector{Int}
    @test msgs == data

    # ZMQ.close(s1); ZMQ.close(s2) # should happen when context is closed
    ZMQ.close(ZMQ._context) # immediately close global context rather than waiting for exit
    @test !isopen(s1)
    @test !isopen(s2)

    # Smoke tests for Base.show() in different Socket situations
    s1 = Socket(REP)
    @test repr(s1) == "Socket(REP)"
    ZMQ.bind(s1, "tcp://127.0.0.1:5555")
    @test repr(s1) == "Socket(REP, tcp://127.0.0.1:5555)"
    close(s1)
    @test repr(s1) == "Socket() (closed)"
end

@testset "Message" begin
    # Test all the send constructors
    s1 = Socket(PUB)
    s2 = Socket(SUB)
    ZMQ.subscribe(s2, "")
    ZMQ.bind(s1, "tcp://*:5555")
    ZMQ.connect(s2, "tcp://localhost:5555")

    # Sleep for a bit to prevent the 'slow joiner' problem
    sleep(0.5)

    # Message(::Int) - construct from buffer size
    data = rand(UInt8, 10)
    m1 = Message(length(data))
    # Note that we don't use copy!() for compatibility with Julia 1.3
    for i in eachindex(data)
        m1[i] = data[i]
    end
    ZMQ.send(s1, m1)
    @test ZMQ.recv(s2) == data

    # Message(::Any, ::Ptr, ::Int) - construct from pointer to existing data
    buffer = rand(UInt8, 10)
    m2 = Message(buffer, pointer(buffer), length(buffer))
    ZMQ.send(s1, m2)
    @test ZMQ.recv(s2) == buffer

    # Message(::String)
    str_msg = "foobar"
    m3 = Message(str_msg)
    ZMQ.send(s1, m3)
    @test String(ZMQ.recv(s2)) == str_msg

    # Message(::SubString)
    m4 = Message(SubString(str_msg, 1:3))
    ZMQ.send(s1, m4)
    @test String(ZMQ.recv(s2)) == str_msg[1:3]

    # Message(::DenseVector) - construct from array
    buffer2 = rand(UInt8, 10)
    m5 = Message(buffer2)
    ZMQ.send(s1, m5)
    @test ZMQ.recv(s2) == buffer2

    # Message(::IOBuffer)
    buffer3 = rand(UInt8, 10)
    iobuf = IOBuffer(buffer3)
    m6 = Message(iobuf)
    ZMQ.send(s1, m6)
    @test ZMQ.recv(s2) == buffer3

    close(iobuf)
    @test_throws ErrorException Message(iobuf)

    close(s1)
    close(s2)

    # Test indexing
    m = Message(10)
    @test_throws BoundsError m[0]
    @test_throws BoundsError m[11]
    @test_throws BoundsError m[0] = 1
    @test_throws BoundsError m[11] = 1

    @test propertynames(m) isa Tuple
    @test_logs (:warn, r"set(.+) is deprecated") (@test_throws StateError ZMQ.set(m, ZMQ.MORE, 1))
    @test (@test_logs (:warn, r"get(.+) is deprecated") get(m, ZMQ.MORE)) == 0
    @test_throws ErrorException m.foo
    @test_throws ErrorException m.more = 1

    # Smoke tests
    @test !Bool(m.more)
    @test_throws ErrorException m.more = true
    @test ZMQ.isfreed(m)
    @test_logs (:warn, r"convert(.+) is deprecated") convert(IOStream, m)
end

@testset "ZMQ resource management" begin
    local leaked_req_socket, leaked_rep_socket
    ZMQ.Socket(ZMQ.REQ) do req_socket
        leaked_req_socket = req_socket

        ZMQ.Socket(ZMQ.REP) do rep_socket
            leaked_rep_socket = rep_socket

            ZMQ.bind(rep_socket, "inproc://tester")
            ZMQ.connect(req_socket, "inproc://tester")

            ZMQ.send(req_socket, "Mr. Watson, come here, I want to see you.")
            @test unsafe_string(ZMQ.recv(rep_socket)) == "Mr. Watson, come here, I want to see you."
            ZMQ.send(rep_socket, "Coming, Mr. Bell.")
            @test unsafe_string(ZMQ.recv(req_socket)) == "Coming, Mr. Bell."
        end

        @test !ZMQ.isopen(leaked_rep_socket)
    end
    @test !ZMQ.isopen(leaked_req_socket)

    local leaked_ctx
    ZMQ.Context() do ctx
        leaked_ctx = ctx

        @test isopen(ctx)
    end
    @test !isopen(leaked_ctx)
end

@testset "ZMQPoll" begin

    ctx = Context()
    req1 = Socket(REQ)
    req12 = Socket(REQ)
    rep1 = Socket(REP)
    rep_trigger = Socket(REP)
    req2 = Socket(REQ)
    rep2 = Socket(REP)
    poller = ZMQ.PollItems([req1, rep1, rep2], [ZMQ.POLLIN, ZMQ.POLLIN, ZMQ.POLLIN])

    timeout_ms = 100

    addr = "inproc://s1"
    addr2 = "inproc://s2"
    trigger_addr = "inproc://s3"
    hi = "Hello"
    bye = "World"

    connect(req1, addr)
    connect(req12, addr)
    bind(rep1, addr)
    bind(rep_trigger, trigger_addr)
    bind(rep2, addr2)
    connect(req2, addr2)

    function async_send(addr, trigger_addr, waiting_time)
        hi = "Hello"
        bye = "World"
        req_alt = Socket(REQ)
        connect(req_alt, addr)
        req_trigger = Socket(REQ)
        connect(req_trigger, trigger_addr)
        send(req_trigger, hi)
        sleep(waiting_time)
        send(req_alt, hi)
        close(req_trigger)
        close(req_alt)
    end

    # Polling multiple items
    # case 1: socket received message before poll
    send(req1, hi)
    @test poll(poller, timeout_ms) == 1
    @test poller.revents[2] == ZMQ.POLLIN
    @test recv(rep1, String) == hi
    send(rep1, bye)
    @test poll(poller, timeout_ms) == 1
    recv(req1)

    # case 2: socket received message during poll
    t = @spawn async_send(addr, trigger_addr, timeout_ms * 1.0e-4)
    recv(rep_trigger)
    @test poll(poller, timeout_ms) == 1
    @test poller.revents[2] == ZMQ.POLLIN
    @test poller.revents[1] == 0
    recv(rep1)
    send(rep1, bye)
    @test poll(poller, timeout_ms) == 0
    send(rep_trigger, bye)
    wait(t)

    # case 3: poll times out
    t = @spawn async_send(addr, trigger_addr, timeout_ms * 2.0e-3)
    recv(rep_trigger)
    @test poll(poller, timeout_ms) == 0
    send(rep_trigger, bye)
    wait(t)
    recv(rep1)
    send(rep1, bye)

    # case 4: blocking poll receive before
    send(req1, hi)
    @test poll(poller) == 1
    @test poller.revents[2] == ZMQ.POLLIN
    @test recv(rep1, String) == hi
    send(rep1, bye)
    @test poll(poller) == 1
    recv(req1)

    # case 5: blocking poll receive during
    t = @spawn async_send(addr, trigger_addr, timeout_ms * 1.0e-4)
    recv(rep_trigger)
    @test poll(poller) == 1
    @test poller.revents[2] == ZMQ.POLLIN
    @test poller.revents[1] == 0
    recv(rep1)
    send(rep1, bye)
    @test poll(poller, 100) == 0
    send(rep_trigger, bye)
    wait(t)

    # case 6: multiple sockets receive before call with timeout
    send(req1, hi)
    send(req2, hi)
    @test poll(poller, timeout_ms) == 2
    @test poller.revents[2] == ZMQ.POLLIN
    @test poller.revents[3] == ZMQ.POLLIN
    @test recv(rep1, String) == hi
    @test recv(rep2, String) == hi
    send(rep1, bye)
    send(rep2, bye)
    @test poll(poller, timeout_ms) == 1 # req2 is not in poller
    recv(req1)
    recv(req2)

    # case 7: multiple sockets receive during call with no timeout
    t1 = @spawn async_send(addr, trigger_addr, timeout_ms * 1.0e-4)
    recv(rep_trigger)
    send(rep_trigger, bye)
    t2 = @spawn async_send(addr2, trigger_addr, timeout_ms * 1.0e-4)
    recv(rep_trigger)
    num_events = poll(poller)
    @test 1 <= num_events <= 2 # could return 1 or 2 events
    @test poller.revents[2] == ZMQ.POLLIN || poller.revents[3] == ZMQ.POLLIN
    # if polled messages are not handled, then the poller will keep indicating them
    poller.revents[2] & ZMQ.POLLIN != 0 && recv(rep1)
    poller.revents[3] & ZMQ.POLLIN != 0 && recv(rep2)
    if num_events == 1
        rest = poll(poller)
    else
        rest = poll(poller, timeout_ms)
    end
    @test num_events + rest == 2 # in total there should have been two events
    poller.revents[2] & ZMQ.POLLIN != 0 && recv(rep1)
    poller.revents[3] & ZMQ.POLLIN != 0 && recv(rep2)
    send(rep1, bye)
    send(rep2, bye)
    send(rep_trigger, bye)
    wait(t1)
    wait(t2)

    # case 8: multiple receives on the same socket
    t1 = @spawn async_send(addr, trigger_addr, timeout_ms * 1.0e-4)
    t2 = @spawn async_send(addr, trigger_addr, timeout_ms * 1.0e-4)
    send(req1, hi)
    send(req12, hi)
    send(req2, hi)
    num_sends = 5
    recv(rep_trigger)
    send(rep_trigger, bye)
    recv(rep_trigger)
    send(rep_trigger, bye)
    counter = 0
    while true
        poll(poller)
        if poller.revents[1] & ZMQ.POLLIN != 0
            recv(req1)
        end
        if poller.revents[2] & ZMQ.POLLIN != 0
            recv(rep1)
            send(rep1, bye)
            counter += 1
            counter == num_sends && break
        end
        if poller.revents[3] & ZMQ.POLLIN != 0
            recv(rep2)
            send(rep2, bye)
            counter += 1
            counter == num_sends && break
        end
    end

    close(poller)
    @test_throws StateError poll(poller, 0)

    # case 9 new poller and first time poll without timeout
    t = @spawn begin
        rep3 = Socket(ctx, REP)
        bind(rep3, "inproc://s3")
        poller = ZMQ.PollItems([rep3], [ZMQ.POLLIN])
        @test poll(poller) == 1
        @test recv(rep3, String) == hi
        send(rep3, bye)
        close(poller)
        close(rep3)
    end
    req3 = Socket(ctx, REQ)
    connect(req3, "inproc://s3")
    send(req3, hi)
    @test recv(req3, String) == bye
    wait(t)


    # test that even without poller sockets still functional
    send(req1, hi)
    @test recv(rep1, String) == hi

    close(req1)
    close(req12)
    close(rep1)
    close(req2)
    close(rep2)
    close(rep_trigger)
    close(ctx)
end

@testset "Utilities" begin
    @test ZMQ.lib_version() isa VersionNumber
end

@testset "Aqua.jl" begin
    Aqua.test_all(ZMQ)
end
