
## Contexts ##
# Provide the same constructor API for version 2 and version 3, even
# though the underlying functions are changing
mutable struct Context
    data::Ptr{Cvoid}

    # need to keep a list of weakrefs to sockets for this Context in order to
    # close them before finalizing (otherwise zmq_term will hang)
    sockets::Vector{WeakRef}

    function Context()
        p = ccall((:zmq_ctx_new, libzmq), Ptr{Cvoid},  ())
        if p == C_NULL
            throw(StateError(jl_zmq_error_str()))
        end
        zctx = new(p, WeakRef[])
        @compat finalizer(close, zctx)
        return zctx
    end
end

@deprecate Context(n::Integer) Context()

function close(ctx::Context)
    if ctx.data != C_NULL # don't close twice!
        data = ctx.data
        ctx.data = C_NULL
        for w in ctx.sockets
            s = w.value
            s isa Socket && close(s)
        end
        rc = ccall((:zmq_ctx_destroy, libzmq), Cint,  (Ptr{Cvoid},), data)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
    end
end
term(ctx::Context) = close(ctx)

function get(ctx::Context, option::Integer)
    val = ccall((:zmq_ctx_get, libzmq), Cint, (Ptr{Cvoid}, Cint), ctx.data, option)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    return val
end

function set(ctx::Context, option::Integer, value::Integer)
    rc = ccall((:zmq_ctx_set, libzmq), Cint, (Ptr{Cvoid}, Cint, Cint), ctx.data, option, value)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end