import Base.Threads: @spawn
import Aqua
using ZMQ, Test

@info("Testing with ZMQ version $(ZMQ.version)")

@testset "ZMQ contexts" begin
    ctx=Context()
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
    @test isopen(s)
end

@testset "ZMQ sockets" begin
    context_gc_test()

    s=Socket(PUB)
    @test s isa Socket
    ZMQ.close(s)

    s1=Socket(REP)
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
        @test m[1]==0x31
        @test (m[1]=0x32) === 0x32
        @test unsafe_string(m)=="2"
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
    rep1 = Socket(REP)
    req2 = Socket(REQ)
    rep2 = Socket(REP)

    bind(req1, "inproc://s1")
    connect(rep1, "inproc://s1")
    bind(req2, "inproc://s2")
    connect(rep2, "inproc://s2")

    poller = PollItems([(req1, ZMQ.POLLIN), (rep1, ZMQ.POLLIN)])
    t = @spawn begin
        recv(rep2)
        sleep(1)
        send(req1, "Hello")
    end
    send(req2, "")
    while true
        i = poll(poller)
        arr = ZMQ.revents(poller)
        if arr[1] & ZMQ.POLLIN > 0
            s = recv(req1, String)
            @test s == "World"
            break
        elseif arr[2] & ZMQ.POLLIN > 0
            s = recv(rep1, String)
            @test s == "Hello"
            send(rep1, "World")
        end
    end

    close(req1)
    close(rep1)
    close(req2)
    close(rep2)
    close(ctx)
end

@testset "Utilities" begin
    @test ZMQ.lib_version() isa VersionNumber
end

@testset "Aqua.jl" begin
    Aqua.test_all(ZMQ)
end
