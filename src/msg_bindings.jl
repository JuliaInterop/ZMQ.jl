import ZeroMQ_jll: libzmq
import .lib: zmq_free_fn

function lib.zmq_msg_init(msg_::Message)
    ccall((:zmq_msg_init, libzmq), Cint, (Ref{Message},), msg_)
end

function lib.zmq_msg_init_size(msg_::Message, size_)
    ccall((:zmq_msg_init_size, libzmq), Cint, (Ref{Message}, Csize_t), msg_, size_)
end

function lib.zmq_msg_init_data(msg_::Message, data_, size_, ffn_, hint_)
    ccall((:zmq_msg_init_data, libzmq), Cint, (Ref{Message}, Ptr{Cvoid}, Csize_t, Ptr{zmq_free_fn}, Ptr{Cvoid}), msg_, data_, size_, ffn_, hint_)
end

function lib.zmq_msg_send(msg_::Message, s_, flags_)
    ccall((:zmq_msg_send, libzmq), Cint, (Ref{Message}, Ptr{Cvoid}, Cint), msg_, s_, flags_)
end

function lib.zmq_msg_recv(msg_::Message, s_, flags_)
    ccall((:zmq_msg_recv, libzmq), Cint, (Ref{Message}, Ptr{Cvoid}, Cint), msg_, s_, flags_)
end

function lib.zmq_msg_close(msg_::Message)
    ccall((:zmq_msg_close, libzmq), Cint, (Ref{Message},), msg_)
end

function lib.zmq_msg_move(dest_::Message, src_)
    ccall((:zmq_msg_move, libzmq), Cint, (Ref{Message}, Ref{Message}), dest_, src_)
end

function lib.zmq_msg_copy(dest_::Message, src_)
    ccall((:zmq_msg_copy, libzmq), Cint, (Ref{Message}, Ref{Message}), dest_, src_)
end

function lib.zmq_msg_data(msg_::Message)
    ccall((:zmq_msg_data, libzmq), Ptr{Cvoid}, (Ref{Message},), msg_)
end

function lib.zmq_msg_size(msg_::Message)
    ccall((:zmq_msg_size, libzmq), Csize_t, (Ref{Message},), msg_)
end

function lib.zmq_msg_more(msg_::Message)
    ccall((:zmq_msg_more, libzmq), Cint, (Ref{Message},), msg_)
end

function lib.zmq_msg_get(msg_::Message, property_)
    ccall((:zmq_msg_get, libzmq), Cint, (Ref{Message}, Cint), msg_, property_)
end

function lib.zmq_msg_set(msg_::Message, property_, optval_)
    ccall((:zmq_msg_set, libzmq), Cint, (Ref{Message}, Cint, Cint), msg_, property_, optval_)
end

function lib.zmq_msg_gets(msg_::Message, property_)
    ccall((:zmq_msg_gets, libzmq), Ptr{Cchar}, (Ref{Message}, Ptr{Cchar}), msg_, property_)
end

