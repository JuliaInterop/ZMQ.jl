# A server will report most errors to the client over a Socket, but
# errors in ZMQ state can't be reported because the socket may be
# corrupted. Therefore, we need an exception type for errors that
# should be reported locally.
struct StateError <: Exception
    msg::AbstractString
end

"""
Exception thrown by the `recv*()` methods if `rcvtimeo` is set and a receive
times out. The timeout itself can be obtained from the `timeout_secs` property
of the exception.
"""
struct TimeoutError <: Exception
    socket_info::String
    timeout_secs::Float64
end

Base.show(io::IO, thiserr::StateError) = print(io, "ZMQ: ", thiserr.msg)

function Base.show(io::IO, thiserr::TimeoutError)
    timeout_str = @sprintf("%.2fs", thiserr.timeout_secs)
    print(io, TimeoutError, ": $(thiserr.socket_info) receive timed out after $(timeout_str)")
end

# Basic functions

function jl_zmq_error_str()
    errno = lib.zmq_errno()
    c_strerror = lib.zmq_strerror(errno)

    if c_strerror != C_NULL
        strerror = unsafe_string(c_strerror)
        return strerror
    else
        return "Unknown error"
    end
end
