import ZeroMQ_jll: libzmq
import .lib: zmq_free_fn

function lib.zmq_msg_init(msg_::Message)
    @ccall libzmq.zmq_msg_init(msg_::Ref{Message})::Cint
end

function lib.zmq_msg_init_size(msg_::Message, size_)
    @ccall libzmq.zmq_msg_init_size(msg_::Ref{Message}, size_::Csize_t)::Cint
end

function lib.zmq_msg_init_data(msg_::Message, data_, size_, ffn_, hint_)
    @ccall libzmq.zmq_msg_init_data(msg_::Ref{Message}, data_::Ptr{Cvoid}, size_::Csize_t, ffn_::Ptr{zmq_free_fn}, hint_::Ptr{Cvoid})::Cint
end

function lib.zmq_msg_send(msg_::Message, s_, flags_)
    @ccall libzmq.zmq_msg_send(msg_::Ref{Message}, s_::Ptr{Cvoid}, flags_::Cint)::Cint
end

function lib.zmq_msg_recv(msg_::Message, s_, flags_)
    @ccall libzmq.zmq_msg_recv(msg_::Ref{Message}, s_::Ptr{Cvoid}, flags_::Cint)::Cint
end

function lib.zmq_msg_close(msg_::Message)
    @ccall libzmq.zmq_msg_close(msg_::Ref{Message})::Cint
end

function lib.zmq_msg_move(dest_::Message, src_)
    @ccall libzmq.zmq_msg_move(dest_::Ref{Message}, src_::Ref{Message})::Cint
end

function lib.zmq_msg_copy(dest_::Message, src_)
    @ccall libzmq.zmq_msg_copy(dest_::Ref{Message}, src_::Ref{Message})::Cint
end

function lib.zmq_msg_data(msg_::Message)
    @ccall libzmq.zmq_msg_data(msg_::Ref{Message})::Ptr{Cvoid}
end

function lib.zmq_msg_size(msg_::Message)
    @ccall libzmq.zmq_msg_size(msg_::Ref{Message})::Csize_t
end

function lib.zmq_msg_more(msg_::Message)
    @ccall libzmq.zmq_msg_more(msg_::Ref{Message})::Cint
end

function lib.zmq_msg_get(msg_::Message, property_)
    @ccall libzmq.zmq_msg_get(msg_::Ref{Message}, property_::Cint)::Cint
end

function lib.zmq_msg_set(msg_::Message, property_, optval_)
    @ccall libzmq.zmq_msg_set(msg_::Ref{Message}, property_::Cint, optval_::Cint)::Cint
end

function lib.zmq_msg_gets(msg_::Message, property_)
    @ccall libzmq.zmq_msg_gets(msg_::Ref{Message}, property_::Ptr{Cchar})::Ptr{Cchar}
end

