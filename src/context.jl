
## Contexts ##

# the low-level context constructor
function _ctx_new()
    p = ccall((:zmq_ctx_new, libzmq), Ptr{Cvoid},  ())
    if p == C_NULL
        throw(StateError(jl_zmq_error_str()))
    end
    return p
end

mutable struct Context
    data::Ptr{Cvoid}

    # need to keep a list of weakrefs to sockets for this Context in order to
    # close them before finalizing (otherwise zmq_term will hang)
    sockets::Vector{WeakRef}

    function Context()
        zctx = new(_ctx_new(), WeakRef[])
        @compat finalizer(close, zctx)
        return zctx
    end
    function Context(::Compat.UndefInitializer)
        zctx = new(C_NULL, WeakRef[])
        @compat finalizer(close, zctx)
        return zctx
    end
end

Base.unsafe_convert(::Type{Ptr{Cvoid}}, c::Context) = c.data

# define a global context that is initialized lazily
# and is used by default in Socket constructors, to
# save 99% of users from the low-level need to set up
# a context
const _context = Context(undef)

"""
    context()

Return the default ZMQ context (of type `Context`), initializing
it if this has not been done already.  (This context is automatically
closed when Julia exits.)
"""
function context()
    if _context.data == C_NULL
        _context.data = _ctx_new()
    end
    return _context
end


@deprecate Context(n::Integer) Context()

function close(ctx::Context)
    if ctx.data != C_NULL # don't close twice!
        for w in ctx.sockets
            s = w.value
            if s isa Socket && s.data != C_NULL
                set_linger(s, 0) # allow socket to shut down immediately
                close(s)
            end
        end
        empty!(ctx.sockets)
        rc = ccall((:zmq_ctx_destroy, libzmq), Cint,  (Ptr{Cvoid},), ctx)
        ctx.data = C_NULL
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
    end
end
term(ctx::Context) = close(ctx)

function get(ctx::Context, option::Integer)
    val = ccall((:zmq_ctx_get, libzmq), Cint, (Ptr{Cvoid}, Cint), ctx, option)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    return val
end

function set(ctx::Context, option::Integer, value::Integer)
    rc = ccall((:zmq_ctx_set, libzmq), Cint, (Ptr{Cvoid}, Cint, Cint), ctx, option, value)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end