# A server will report most errors to the client over a Socket, but
# errors in ZMQ state can't be reported because the socket may be
# corrupted. Therefore, we need an exception type for errors that
# should be reported locally.
struct StateError <: Exception
    msg::AbstractString
end
show(io, thiserr::StateError) = print(io, "ZMQ: ", thiserr.msg)

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
