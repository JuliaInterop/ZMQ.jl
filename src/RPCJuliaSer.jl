require("ZMQ")

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

require("ZMQ/src/zmq_serialize_julia")
require("ZMQ/src/zmq_client_julia")
require("ZMQ/src/zmq_server_julia")

end
