
## Contexts ##

# the low-level context constructor
function _ctx_new()
    p = lib.zmq_ctx_new()
    if p == C_NULL
        throw(StateError(jl_zmq_error_str()))
    end
    return p
end

mutable struct Context
    data::Ptr{Cvoid}

    # need to keep a list of weakrefs to sockets for this Context in order to
    # close them before finalizing (otherwise zmq_ctx_term will hang)
    sockets::Vector{WeakRef}

    function Context()
        zctx = new(_ctx_new(), WeakRef[])
        finalizer(close, zctx)
        return zctx
    end
    function Context(::UndefInitializer)
        zctx = new(C_NULL, WeakRef[])
        finalizer(close, zctx)
        return zctx
    end
end

function Context(f::Function, args...)
    ctx = Context(args...)
    try
        f(ctx)
    finally
        close(ctx)
    end
end

function Base.show(io::IO, ctx::Context)
    if isopen(ctx)
        print(io, Context, "($(getfield(ctx, :sockets)))")
    else
        print(io, Context, "([closed])")
    end
end

Base.unsafe_convert(::Type{Ptr{Cvoid}}, c::Context) = getfield(c, :data)

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
    if !isopen(_context)
        setfield!(_context, :data, _ctx_new())
    end
    return _context
end

@deprecate Context(n::Integer) Context()

Base.isopen(ctx::Context) = getfield(ctx, :data) != C_NULL
function Base.close(ctx::Context)
    if isopen(ctx) # don't close twice!
        for w in getfield(ctx, :sockets)
            s = w.value
            if s isa Socket && isopen(s)
                s.linger = 0 # allow socket to shut down immediately
                close(s)
            end
        end
        empty!(getfield(ctx, :sockets))
        rc = lib.zmq_ctx_term(ctx)
        setfield!(ctx, :data, C_NULL)
        if rc != 0
            throw(StateError(jl_zmq_error_str()))
        end
    end
end
@deprecate term(ctx::Context) close(ctx)

function _get(ctx::Context, option::Integer)
    val = lib.zmq_ctx_get(ctx, option)
    if val < 0
        throw(StateError(jl_zmq_error_str()))
    end
    return val
end
function _set(ctx::Context, option::Integer, value::Integer)
    rc = lib.zmq_ctx_set(ctx, option, value)
    if rc != 0
        throw(StateError(jl_zmq_error_str()))
    end
end

const ctxopts = (:io_threads, :max_sockets, :ipv6)
Base.propertynames(::Context) = ctxopts
@eval function Base.getproperty(value::Context, name::Symbol)
    $(propexpression(ctxopts) do p
        :(_get(value, $(Symbol(uppercase(String(p))))))
    end)
end
@eval function Base.setproperty!(value::Context, name::Symbol, x::Integer)
    $(propexpression(ctxopts) do p
        :(_set(value, $(Symbol(uppercase(String(p)))), x))
    end)
    return x
end

function Base.get(ctx::Context, option::Integer)
    Base.depwarn("get(ctx, option) is deprecated; use ctx.option instead", :get)
    return _get(ctx, option)
end
function set(ctx::Context, option::Integer, value::Integer)
    Base.depwarn("set(ctx, option, val) is deprecated; use ctx.option = val instead", :set)
    return _set(ctx, option, value)
end
