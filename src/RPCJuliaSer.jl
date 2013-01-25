module RPCJuliaSer
using Base
using ZMQ

export 
    #zmq_serialize_julia
    zmq_serialize,zmq_deserialize,  
    #zmq_client_julia 
    launch_client,zmqcall,zmqparse,zmqsetvar,zmqgetvar,
    #zmq_server_julia
    run_server,zmqquit,parse_eval

include("zmq_serialize_julia.jl")
include("zmq_client_julia.jl")
include("zmq_server_julia.jl")

end
