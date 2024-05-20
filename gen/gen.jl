import Clang
import ZeroMQ_jll
import MacroTools: @capture, postwalk, prettify


# Helper function to look through all the generated bindings and create new
# zmq_msg_* methods for the Message type. We need to create these overloads
# because the Message type relies on _Message (i.e. lib.zmq_msg_t) under the
# hood, and _Message is an immutable type so it doesn't have a stable address,
# and so cannot safely be passed to a ccall.
#
# We get around this for _Message by always using a Ref{_Message}, but Message
# is a mutable struct with a _Message as its first field. It's safe to pass a
# pointer to a Message to libzmq because the address of the Message is the same
# as its first field, the _Message. But to do that we need to create methods to
# ccall libzmq with the Message type instead of lib.zmq_msg_t (_Message).
function get_msg_methods(ctx, module_name)
    methods = Expr[]

    for node in ctx.dag.nodes
        for i in eachindex(node.exprs)
            expr = node.exprs[i]

            # Check if this is a function
            if @capture(expr, function name_(arg1_, args__) body_ end)
                # Check if it's a zmq_msg_* function
                if startswith(string(name), "zmq_msg_")
                    # Replace occurrences of `arg::Ptr{zmq_msg_t}` with
                    # `arg::Ref{Message}`.
                    new_body = postwalk(body) do x
                        if @capture(x, arg_name_::T_) && T == :(Ptr{zmq_msg_t})
                            :($arg_name::Ref{Message})
                        else
                            x
                        end
                    end

                    # Create the new method
                    new_method = quote
                        function $module_name.$name($arg1::Message, $(args...))
                            $new_body
                        end
                    end

                    push!(methods, prettify(new_method))
                end
            end
        end
    end

    return methods
end

cd(@__DIR__) do
    # Set the options
    options = Clang.load_options(joinpath(@__DIR__, "generator.toml"))
    header = joinpath(ZeroMQ_jll.artifact_dir, "include", "zmq.h")
    args = Clang.get_default_args()

    # Generate the generic bindings
    ctx = Clang.create_context([header], args, options)
    Clang.build!(ctx)

    # Generate the Message methods we need
    module_name = Symbol(options["general"]["module_name"])
    msg_methods = get_msg_methods(ctx, module_name)
    output_file = joinpath(@__DIR__, "../src/msg_bindings.jl")
    open(output_file; write=true) do io
        # Import symbols required by the bindings
        write(io, "import ZeroMQ_jll: libzmq\n")
        write(io, "import .lib: zmq_free_fn\n\n")

        for expr in msg_methods
            write(io, string(expr), "\n\n")
        end
    end
end
