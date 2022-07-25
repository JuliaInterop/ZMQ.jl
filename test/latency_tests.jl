using Dates
using Statistics

@show Threads.nthreads()

@testset "Latency tests" begin
    function send_messages(socket::ZMQ.Socket, msg, N::Int, Δt::TimePeriod, ready_to_start::Channel{Nothing}, start_condition::Threads.Condition)
        timestamps = Nanosecond[]    
        @info "Sender ready to start on thread $(Threads.threadid())"
        put!(ready_to_start, nothing)
        lock(start_condition) do
            wait(start_condition)          
        end
        @info "Sender starting"
        for _ in 1:N
            sleep(Δt)
            ZMQ.send(socket, msg)
            push!(timestamps, Nanosecond(time_ns()))
        end
        return timestamps
    end
    
    function receive_messages(socket::ZMQ.Socket, N::Int, ready_to_start::Channel{Nothing}, start_condition::Threads.Condition)
        timestamps = Nanosecond[]
        @info "Receiver ready to start on thread $(Threads.threadid())"
        put!(ready_to_start, nothing)
        lock(start_condition) do
            wait(start_condition)          
        end
        @info "Receiver starting"
        for _ in 1:N
            ZMQ.recv(socket)
            push!(timestamps, Nanosecond(time_ns()))
        end
        return timestamps
    end
    
    function time_parallel_send_receive(send_socket, recv_socket, msg, N::Int, Δt::TimePeriod)
        ready_to_start = Channel{Nothing}(2)
        start_condition = Threads.Condition()
        
        sender = Threads.@spawn send_messages(send_socket, msg, N, Δt, ready_to_start, start_condition)
        receiver = Threads.@spawn receive_messages(recv_socket, N, ready_to_start, start_condition)
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
        @testset "PUSH/PULL with period $period_ms ms" begin
            N = 1000 # Number of messages
            Δt = Millisecond(period_ms)
            msg = [0x1]
            
            expected_max_latency = Microsecond(1000)
            expected_mean = Dates.toms(Δt)
            expected_median = expected_mean
            expected_tol = Dates.toms(Millisecond(5))
            expected_max_tol = Dates.toms(Millisecond(10))
            
            ctx = ZMQ.context()
            send_socket = Socket(ctx, PUSH)
            bind(send_socket, "tcp://*:6666")
            recv_socket = Socket(ctx, PULL)
            connect(recv_socket, "tcp://localhost:6666")
            
            try
                push_timestamps, pull_timestamps = time_parallel_send_receive(send_socket, recv_socket, msg, N, Δt)
                test_timestamps(push_timestamps, pull_timestamps, N, expected_max_latency, expected_mean, expected_median, expected_tol, expected_max_tol)
            finally
                close(send_socket)
                close(recv_socket)
                close(ctx)
            end  
        end
    end
end
