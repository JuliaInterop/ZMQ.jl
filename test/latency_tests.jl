using Dates
using Statistics

@show Threads.nthreads()

@testset "Latency tests" begin
    function send_messages(ctx::ZMQ.Context, msg, N::Int, Δt::TimePeriod, ready_to_start::Channel{Nothing}, start_condition::Threads.Condition)
        socket = Socket(ctx, REP)
        try
            bind(socket, "tcp://*:6666")
            timestamps = Nanosecond[]
            @info "Sender ready to start on thread $(Threads.threadid())"
            put!(ready_to_start, nothing)
            lock(start_condition) do
                wait(start_condition)          
            end
            @info "Sender starting"
            for _ in 1:N
                sleep(Δt)
                ZMQ.recv(socket)
                ZMQ.send(socket, msg)
                push!(timestamps, Nanosecond(time_ns()))
            end
            return timestamps
        finally
            close(socket)
        end
    end
    
    function receive_messages(ctx::ZMQ.Context, N::Int, ready_to_start::Channel{Nothing}, start_condition::Threads.Condition)
        socket = Socket(ctx, REQ)
        msg = [0x1]
        try
            connect(socket, "tcp://localhost:6666")
            timestamps = Nanosecond[]
            @info "Receiver ready to start on thread $(Threads.threadid())"
            put!(ready_to_start, nothing)
            lock(start_condition) do
                wait(start_condition)          
            end
            @info "Receiver starting"
            for _ in 1:N
                ZMQ.send(socket, msg)
                ZMQ.recv(socket)
                push!(timestamps, Nanosecond(time_ns()))
            end
            return timestamps
        finally
            close(socket)
        end
    end
    
    function time_parallel_send_receive(ctx::ZMQ.Context, msg, N::Int, Δt::TimePeriod)
        ready_to_start = Channel{Nothing}(2)
        start_condition = Threads.Condition()
        
        sender = Threads.@spawn send_messages(ctx, msg, N, Δt, ready_to_start, start_condition)
        receiver = Threads.@spawn receive_messages(ctx, N, ready_to_start, start_condition)
        @info "Awaiting ready_to_start"
        for _ in 1:2
            take!(ready_to_start)
        end
        @info "Starting"
        lock(start_condition) do
            notify(start_condition)          
        end
        @info "Awaiting completion"
        send_timestamps = fetch(sender)
        recv_timestamps = fetch(receiver)
        
        return send_timestamps, recv_timestamps
    end
    
    function test_timestamps(send_timestamps, recv_timestamps, N, expected_max_latency, expected_mean, expected_median, expected_tol, max_tol)
        @assert length(send_timestamps) == N
        @assert length(recv_timestamps) == N
        
        latencies = recv_timestamps .- send_timestamps
        Δsend_timestamps = [Dates.toms(send_timestamps[i] - send_timestamps[i-1]) for i in 2:N]
        Δrecv_timestamps = [Dates.toms(recv_timestamps[i] - recv_timestamps[i-1]) for i in 2:N]
        
        @show maximum(latencies)
        @test maximum(latencies) <= expected_max_latency
        
        @show mean(Δsend_timestamps)
        @test mean(Δsend_timestamps) ≈ expected_mean atol=expected_tol
        @show median(Δsend_timestamps)
        @test median(Δsend_timestamps) ≈ expected_median atol=expected_tol
        @show std(Δsend_timestamps)
        @test std(Δsend_timestamps) < expected_tol
        @show maximum(Δsend_timestamps)
        @test maximum(Δsend_timestamps) < expected_mean+max_tol
        
        @show mean(Δrecv_timestamps)
        @test mean(Δrecv_timestamps) ≈ expected_mean atol=expected_tol
        @show median(Δrecv_timestamps)
        @test median(Δrecv_timestamps) ≈ expected_median atol=expected_tol
        @show std(Δrecv_timestamps)
        @test std(Δrecv_timestamps) < expected_tol
        @show maximum(Δrecv_timestamps)
        @test maximum(Δrecv_timestamps) < expected_mean+max_tol
    end

    for period_ms in [2^n for n in 0:4]
        @testset "REQ/REP with period $period_ms ms" begin
            N = 1000 # Number of messages
            Δt = Millisecond(period_ms)
            msg = [0x1]
            
            expected_max_latency = Microsecond(1000)
            expected_mean = Dates.toms(Δt)
            expected_median = expected_mean
            expected_tol = Dates.toms(Millisecond(5))
            expected_max_tol = Dates.toms(Millisecond(10))
            
            ctx = ZMQ.context()
            @show ctx.io_threads
            
            try
                push_timestamps, pull_timestamps = time_parallel_send_receive(ctx, msg, N, Δt)
                test_timestamps(push_timestamps, pull_timestamps, N, expected_max_latency, expected_mean, expected_median, expected_tol, expected_max_tol)
            finally
                close(ctx)
            end  
        end
    end
end
