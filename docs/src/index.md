# ZMQ.jl

*A Julia interface to ZeroMQ.*

**ZMQ.jl** is a [Julia](http://julialang.org) interface to [ZeroMQ, The
Intelligent Transport Layer](http://zeromq.org).

## Package Features

- Access ZeroMQ sockets from Julia

The [Guide](@ref) provides a tutorial explaining how to get started using ZMQ.jl.

Some examples are linked on the [Examples](@ref) page.

See the [Reference](@ref) for the complete list of wrapped functions and types.

!!! danger
    This library is a thin layer on top of ZeroMQ, and as such has mostly the
    same threadsafety support: not a lot. None of the functions in ZMQ.jl are
    threadsafe unless explicitly documented otherwise.
