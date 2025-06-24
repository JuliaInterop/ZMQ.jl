module lib

import ZeroMQ_jll: libzmq


"""
    zmq_errno()

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_errno.html).
"""
function zmq_errno()
    ccall((:zmq_errno, libzmq), Cint, ())
end

"""
    zmq_strerror(errnum_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_strerror.html).
"""
function zmq_strerror(errnum_)
    ccall((:zmq_strerror, libzmq), Ptr{Cchar}, (Cint,), errnum_)
end

"""
    zmq_version(major_, minor_, patch_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_version.html).
"""
function zmq_version(major_, minor_, patch_)
    ccall((:zmq_version, libzmq), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major_, minor_, patch_)
end

"""
    zmq_ctx_new()

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_ctx_new.html).
"""
function zmq_ctx_new()
    ccall((:zmq_ctx_new, libzmq), Ptr{Cvoid}, ())
end

"""
    zmq_ctx_term(context_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_ctx_term.html).
"""
function zmq_ctx_term(context_)
    ccall((:zmq_ctx_term, libzmq), Cint, (Ptr{Cvoid},), context_)
end

"""
    zmq_ctx_shutdown(context_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_ctx_shutdown.html).
"""
function zmq_ctx_shutdown(context_)
    ccall((:zmq_ctx_shutdown, libzmq), Cint, (Ptr{Cvoid},), context_)
end

"""
    zmq_ctx_set(context_, option_, optval_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_ctx_set.html).
"""
function zmq_ctx_set(context_, option_, optval_)
    ccall((:zmq_ctx_set, libzmq), Cint, (Ptr{Cvoid}, Cint, Cint), context_, option_, optval_)
end

"""
    zmq_ctx_get(context_, option_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_ctx_get.html).
"""
function zmq_ctx_get(context_, option_)
    ccall((:zmq_ctx_get, libzmq), Cint, (Ptr{Cvoid}, Cint), context_, option_)
end

struct zmq_msg_t
    data::NTuple{64, UInt8}
end

function Base.getproperty(x::Ptr{zmq_msg_t}, f::Symbol)
    f === :_ && return Ptr{NTuple{64, Cuchar}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::zmq_msg_t, f::Symbol)
    r = Ref{zmq_msg_t}(x)
    ptr = Base.unsafe_convert(Ptr{zmq_msg_t}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{zmq_msg_t}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

# typedef void ( zmq_free_fn ) ( void * data_ , void * hint_ )
const zmq_free_fn = Cvoid

"""
    zmq_msg_init(msg_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_init.html).
"""
function zmq_msg_init(msg_)
    ccall((:zmq_msg_init, libzmq), Cint, (Ptr{zmq_msg_t},), msg_)
end

"""
    zmq_msg_init_size(msg_, size_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_init_size.html).
"""
function zmq_msg_init_size(msg_, size_)
    ccall((:zmq_msg_init_size, libzmq), Cint, (Ptr{zmq_msg_t}, Csize_t), msg_, size_)
end

"""
    zmq_msg_init_data(msg_, data_, size_, ffn_, hint_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_init_data.html).
"""
function zmq_msg_init_data(msg_, data_, size_, ffn_, hint_)
    ccall((:zmq_msg_init_data, libzmq), Cint, (Ptr{zmq_msg_t}, Ptr{Cvoid}, Csize_t, Ptr{zmq_free_fn}, Ptr{Cvoid}), msg_, data_, size_, ffn_, hint_)
end

"""
    zmq_msg_send(msg_, s_, flags_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_send.html).
"""
function zmq_msg_send(msg_, s_, flags_)
    ccall((:zmq_msg_send, libzmq), Cint, (Ptr{zmq_msg_t}, Ptr{Cvoid}, Cint), msg_, s_, flags_)
end

"""
    zmq_msg_recv(msg_, s_, flags_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_recv.html).
"""
function zmq_msg_recv(msg_, s_, flags_)
    ccall((:zmq_msg_recv, libzmq), Cint, (Ptr{zmq_msg_t}, Ptr{Cvoid}, Cint), msg_, s_, flags_)
end

"""
    zmq_msg_close(msg_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_close.html).
"""
function zmq_msg_close(msg_)
    ccall((:zmq_msg_close, libzmq), Cint, (Ptr{zmq_msg_t},), msg_)
end

"""
    zmq_msg_move(dest_, src_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_move.html).
"""
function zmq_msg_move(dest_, src_)
    ccall((:zmq_msg_move, libzmq), Cint, (Ptr{zmq_msg_t}, Ptr{zmq_msg_t}), dest_, src_)
end

"""
    zmq_msg_copy(dest_, src_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_copy.html).
"""
function zmq_msg_copy(dest_, src_)
    ccall((:zmq_msg_copy, libzmq), Cint, (Ptr{zmq_msg_t}, Ptr{zmq_msg_t}), dest_, src_)
end

"""
    zmq_msg_data(msg_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_data.html).
"""
function zmq_msg_data(msg_)
    ccall((:zmq_msg_data, libzmq), Ptr{Cvoid}, (Ptr{zmq_msg_t},), msg_)
end

"""
    zmq_msg_size(msg_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_size.html).
"""
function zmq_msg_size(msg_)
    ccall((:zmq_msg_size, libzmq), Csize_t, (Ptr{zmq_msg_t},), msg_)
end

"""
    zmq_msg_more(msg_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_more.html).
"""
function zmq_msg_more(msg_)
    ccall((:zmq_msg_more, libzmq), Cint, (Ptr{zmq_msg_t},), msg_)
end

"""
    zmq_msg_get(msg_, property_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_get.html).
"""
function zmq_msg_get(msg_, property_)
    ccall((:zmq_msg_get, libzmq), Cint, (Ptr{zmq_msg_t}, Cint), msg_, property_)
end

"""
    zmq_msg_set(msg_, property_, optval_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_set.html).
"""
function zmq_msg_set(msg_, property_, optval_)
    ccall((:zmq_msg_set, libzmq), Cint, (Ptr{zmq_msg_t}, Cint, Cint), msg_, property_, optval_)
end

"""
    zmq_msg_gets(msg_, property_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_msg_gets.html).
"""
function zmq_msg_gets(msg_, property_)
    ccall((:zmq_msg_gets, libzmq), Ptr{Cchar}, (Ptr{zmq_msg_t}, Ptr{Cchar}), msg_, property_)
end

"""
    zmq_socket(arg1, type_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_socket.html).
"""
function zmq_socket(arg1, type_)
    ccall((:zmq_socket, libzmq), Ptr{Cvoid}, (Ptr{Cvoid}, Cint), arg1, type_)
end

"""
    zmq_close(s_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_close.html).
"""
function zmq_close(s_)
    ccall((:zmq_close, libzmq), Cint, (Ptr{Cvoid},), s_)
end

"""
    zmq_setsockopt(s_, option_, optval_, optvallen_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_setsockopt.html).
"""
function zmq_setsockopt(s_, option_, optval_, optvallen_)
    ccall((:zmq_setsockopt, libzmq), Cint, (Ptr{Cvoid}, Cint, Ptr{Cvoid}, Csize_t), s_, option_, optval_, optvallen_)
end

"""
    zmq_getsockopt(s_, option_, optval_, optvallen_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_getsockopt.html).
"""
function zmq_getsockopt(s_, option_, optval_, optvallen_)
    ccall((:zmq_getsockopt, libzmq), Cint, (Ptr{Cvoid}, Cint, Ptr{Cvoid}, Ptr{Csize_t}), s_, option_, optval_, optvallen_)
end

"""
    zmq_bind(s_, addr_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_bind.html).
"""
function zmq_bind(s_, addr_)
    ccall((:zmq_bind, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cchar}), s_, addr_)
end

"""
    zmq_connect(s_, addr_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_connect.html).
"""
function zmq_connect(s_, addr_)
    ccall((:zmq_connect, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cchar}), s_, addr_)
end

"""
    zmq_unbind(s_, addr_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_unbind.html).
"""
function zmq_unbind(s_, addr_)
    ccall((:zmq_unbind, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cchar}), s_, addr_)
end

"""
    zmq_disconnect(s_, addr_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_disconnect.html).
"""
function zmq_disconnect(s_, addr_)
    ccall((:zmq_disconnect, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cchar}), s_, addr_)
end

"""
    zmq_send(s_, buf_, len_, flags_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_send.html).
"""
function zmq_send(s_, buf_, len_, flags_)
    ccall((:zmq_send, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Cint), s_, buf_, len_, flags_)
end

"""
    zmq_send_const(s_, buf_, len_, flags_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_send_const.html).
"""
function zmq_send_const(s_, buf_, len_, flags_)
    ccall((:zmq_send_const, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Cint), s_, buf_, len_, flags_)
end

"""
    zmq_recv(s_, buf_, len_, flags_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_recv.html).
"""
function zmq_recv(s_, buf_, len_, flags_)
    ccall((:zmq_recv, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Cint), s_, buf_, len_, flags_)
end

"""
    zmq_socket_monitor(s_, addr_, events_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_socket_monitor.html).
"""
function zmq_socket_monitor(s_, addr_, events_)
    ccall((:zmq_socket_monitor, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cchar}, Cint), s_, addr_, events_)
end

const zmq_fd_t = Cint

mutable struct zmq_pollitem_t
    socket::Ptr{Cvoid}
    fd::zmq_fd_t
    events::Cshort
    revents::Cshort
end

"""
    zmq_poll(items_, nitems_, timeout_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_poll.html).
"""
function zmq_poll(items_, nitems_, timeout_)
    ccall((:zmq_poll, libzmq), Cint, (Ptr{zmq_pollitem_t}, Cint, Clong), items_, nitems_, timeout_)
end

"""
    zmq_proxy(frontend_, backend_, capture_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_proxy.html).
"""
function zmq_proxy(frontend_, backend_, capture_)
    ccall((:zmq_proxy, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), frontend_, backend_, capture_)
end

"""
    zmq_proxy_steerable(frontend_, backend_, capture_, control_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_proxy_steerable.html).
"""
function zmq_proxy_steerable(frontend_, backend_, capture_, control_)
    ccall((:zmq_proxy_steerable, libzmq), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), frontend_, backend_, capture_, control_)
end

"""
    zmq_has(capability_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_has.html).
"""
function zmq_has(capability_)
    ccall((:zmq_has, libzmq), Cint, (Ptr{Cchar},), capability_)
end

"""
    zmq_z85_encode(dest_, data_, size_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_z85_encode.html).
"""
function zmq_z85_encode(dest_, data_, size_)
    ccall((:zmq_z85_encode, libzmq), Ptr{Cchar}, (Ptr{Cchar}, Ptr{UInt8}, Csize_t), dest_, data_, size_)
end

"""
    zmq_z85_decode(dest_, string_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_z85_decode.html).
"""
function zmq_z85_decode(dest_, string_)
    ccall((:zmq_z85_decode, libzmq), Ptr{UInt8}, (Ptr{UInt8}, Ptr{Cchar}), dest_, string_)
end

"""
    zmq_curve_keypair(z85_public_key_, z85_secret_key_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_curve_keypair.html).
"""
function zmq_curve_keypair(z85_public_key_, z85_secret_key_)
    ccall((:zmq_curve_keypair, libzmq), Cint, (Ptr{Cchar}, Ptr{Cchar}), z85_public_key_, z85_secret_key_)
end

"""
    zmq_curve_public(z85_public_key_, z85_secret_key_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_curve_public.html).
"""
function zmq_curve_public(z85_public_key_, z85_secret_key_)
    ccall((:zmq_curve_public, libzmq), Cint, (Ptr{Cchar}, Ptr{Cchar}), z85_public_key_, z85_secret_key_)
end

"""
    zmq_atomic_counter_new()

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_atomic_counter_new.html).
"""
function zmq_atomic_counter_new()
    ccall((:zmq_atomic_counter_new, libzmq), Ptr{Cvoid}, ())
end

"""
    zmq_atomic_counter_set(counter_, value_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_atomic_counter_set.html).
"""
function zmq_atomic_counter_set(counter_, value_)
    ccall((:zmq_atomic_counter_set, libzmq), Cvoid, (Ptr{Cvoid}, Cint), counter_, value_)
end

"""
    zmq_atomic_counter_inc(counter_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_atomic_counter_inc.html).
"""
function zmq_atomic_counter_inc(counter_)
    ccall((:zmq_atomic_counter_inc, libzmq), Cint, (Ptr{Cvoid},), counter_)
end

"""
    zmq_atomic_counter_dec(counter_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_atomic_counter_dec.html).
"""
function zmq_atomic_counter_dec(counter_)
    ccall((:zmq_atomic_counter_dec, libzmq), Cint, (Ptr{Cvoid},), counter_)
end

"""
    zmq_atomic_counter_value(counter_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_atomic_counter_value.html).
"""
function zmq_atomic_counter_value(counter_)
    ccall((:zmq_atomic_counter_value, libzmq), Cint, (Ptr{Cvoid},), counter_)
end

"""
    zmq_atomic_counter_destroy(counter_p_)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_atomic_counter_destroy.html).
"""
function zmq_atomic_counter_destroy(counter_p_)
    ccall((:zmq_atomic_counter_destroy, libzmq), Cvoid, (Ptr{Ptr{Cvoid}},), counter_p_)
end

# typedef void ( zmq_timer_fn ) ( int timer_id , void * arg )
const zmq_timer_fn = Cvoid

"""
    zmq_timers_new()

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_new()
    ccall((:zmq_timers_new, libzmq), Ptr{Cvoid}, ())
end

"""
    zmq_timers_destroy(timers_p)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_destroy(timers_p)
    ccall((:zmq_timers_destroy, libzmq), Cint, (Ptr{Ptr{Cvoid}},), timers_p)
end

"""
    zmq_timers_add(timers, interval, handler, arg)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_add(timers, interval, handler, arg)
    ccall((:zmq_timers_add, libzmq), Cint, (Ptr{Cvoid}, Csize_t, zmq_timer_fn, Ptr{Cvoid}), timers, interval, handler, arg)
end

"""
    zmq_timers_cancel(timers, timer_id)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_cancel(timers, timer_id)
    ccall((:zmq_timers_cancel, libzmq), Cint, (Ptr{Cvoid}, Cint), timers, timer_id)
end

"""
    zmq_timers_set_interval(timers, timer_id, interval)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_set_interval(timers, timer_id, interval)
    ccall((:zmq_timers_set_interval, libzmq), Cint, (Ptr{Cvoid}, Cint, Csize_t), timers, timer_id, interval)
end

"""
    zmq_timers_reset(timers, timer_id)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_reset(timers, timer_id)
    ccall((:zmq_timers_reset, libzmq), Cint, (Ptr{Cvoid}, Cint), timers, timer_id)
end

"""
    zmq_timers_timeout(timers)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_timeout(timers)
    ccall((:zmq_timers_timeout, libzmq), Clong, (Ptr{Cvoid},), timers)
end

"""
    zmq_timers_execute(timers)

[Upstream documentation](https://libzmq.readthedocs.io/en/latest/zmq_timers.html).
"""
function zmq_timers_execute(timers)
    ccall((:zmq_timers_execute, libzmq), Cint, (Ptr{Cvoid},), timers)
end

"""
    zmq_stopwatch_start()

This is an undocumented function, not part of the formal ZMQ API.
"""
function zmq_stopwatch_start()
    ccall((:zmq_stopwatch_start, libzmq), Ptr{Cvoid}, ())
end

"""
    zmq_stopwatch_intermediate(watch_)

This is an undocumented function, not part of the formal ZMQ API.
"""
function zmq_stopwatch_intermediate(watch_)
    ccall((:zmq_stopwatch_intermediate, libzmq), Culong, (Ptr{Cvoid},), watch_)
end

"""
    zmq_stopwatch_stop(watch_)

This is an undocumented function, not part of the formal ZMQ API.
"""
function zmq_stopwatch_stop(watch_)
    ccall((:zmq_stopwatch_stop, libzmq), Culong, (Ptr{Cvoid},), watch_)
end

"""
    zmq_sleep(seconds_)

This is an undocumented function, not part of the formal ZMQ API.
"""
function zmq_sleep(seconds_)
    ccall((:zmq_sleep, libzmq), Cvoid, (Cint,), seconds_)
end

# typedef void ( zmq_thread_fn ) ( void * )
const zmq_thread_fn = Cvoid

"""
    zmq_threadstart(func_, arg_)

This is an undocumented function, not part of the formal ZMQ API.
"""
function zmq_threadstart(func_, arg_)
    ccall((:zmq_threadstart, libzmq), Ptr{Cvoid}, (Ptr{zmq_thread_fn}, Ptr{Cvoid}), func_, arg_)
end

"""
    zmq_threadclose(thread_)

This is an undocumented function, not part of the formal ZMQ API.
"""
function zmq_threadclose(thread_)
    ccall((:zmq_threadclose, libzmq), Cvoid, (Ptr{Cvoid},), thread_)
end

const ZMQ_VERSION_MAJOR = 4

const ZMQ_VERSION_MINOR = 3

const ZMQ_VERSION_PATCH = 5

# Skipping MacroDefinition: ZMQ_EXPORT __attribute__ ( ( visibility ( "default" ) ) )

const ZMQ_DEFINED_STDINT = 1

const ZMQ_HAUSNUMERO = 156384712

const EFSM = ZMQ_HAUSNUMERO + 51

const ENOCOMPATPROTO = ZMQ_HAUSNUMERO + 52

const ETERM = ZMQ_HAUSNUMERO + 53

const EMTHREAD = ZMQ_HAUSNUMERO + 54

const ZMQ_IO_THREADS = 1

const ZMQ_MAX_SOCKETS = 2

const ZMQ_SOCKET_LIMIT = 3

const ZMQ_THREAD_PRIORITY = 3

const ZMQ_THREAD_SCHED_POLICY = 4

const ZMQ_MAX_MSGSZ = 5

const ZMQ_MSG_T_SIZE = 6

const ZMQ_THREAD_AFFINITY_CPU_ADD = 7

const ZMQ_THREAD_AFFINITY_CPU_REMOVE = 8

const ZMQ_THREAD_NAME_PREFIX = 9

const ZMQ_IO_THREADS_DFLT = 1

const ZMQ_MAX_SOCKETS_DFLT = 1023

const ZMQ_THREAD_PRIORITY_DFLT = -1

const ZMQ_THREAD_SCHED_POLICY_DFLT = -1

const ZMQ_PAIR = 0

const ZMQ_PUB = 1

const ZMQ_SUB = 2

const ZMQ_REQ = 3

const ZMQ_REP = 4

const ZMQ_DEALER = 5

const ZMQ_ROUTER = 6

const ZMQ_PULL = 7

const ZMQ_PUSH = 8

const ZMQ_XPUB = 9

const ZMQ_XSUB = 10

const ZMQ_STREAM = 11

const ZMQ_XREQ = ZMQ_DEALER

const ZMQ_XREP = ZMQ_ROUTER

const ZMQ_AFFINITY = 4

const ZMQ_ROUTING_ID = 5

const ZMQ_SUBSCRIBE = 6

const ZMQ_UNSUBSCRIBE = 7

const ZMQ_RATE = 8

const ZMQ_RECOVERY_IVL = 9

const ZMQ_SNDBUF = 11

const ZMQ_RCVBUF = 12

const ZMQ_RCVMORE = 13

const ZMQ_FD = 14

const ZMQ_EVENTS = 15

const ZMQ_TYPE = 16

const ZMQ_LINGER = 17

const ZMQ_RECONNECT_IVL = 18

const ZMQ_BACKLOG = 19

const ZMQ_RECONNECT_IVL_MAX = 21

const ZMQ_MAXMSGSIZE = 22

const ZMQ_SNDHWM = 23

const ZMQ_RCVHWM = 24

const ZMQ_MULTICAST_HOPS = 25

const ZMQ_RCVTIMEO = 27

const ZMQ_SNDTIMEO = 28

const ZMQ_LAST_ENDPOINT = 32

const ZMQ_ROUTER_MANDATORY = 33

const ZMQ_TCP_KEEPALIVE = 34

const ZMQ_TCP_KEEPALIVE_CNT = 35

const ZMQ_TCP_KEEPALIVE_IDLE = 36

const ZMQ_TCP_KEEPALIVE_INTVL = 37

const ZMQ_IMMEDIATE = 39

const ZMQ_XPUB_VERBOSE = 40

const ZMQ_ROUTER_RAW = 41

const ZMQ_IPV6 = 42

const ZMQ_MECHANISM = 43

const ZMQ_PLAIN_SERVER = 44

const ZMQ_PLAIN_USERNAME = 45

const ZMQ_PLAIN_PASSWORD = 46

const ZMQ_CURVE_SERVER = 47

const ZMQ_CURVE_PUBLICKEY = 48

const ZMQ_CURVE_SECRETKEY = 49

const ZMQ_CURVE_SERVERKEY = 50

const ZMQ_PROBE_ROUTER = 51

const ZMQ_REQ_CORRELATE = 52

const ZMQ_REQ_RELAXED = 53

const ZMQ_CONFLATE = 54

const ZMQ_ZAP_DOMAIN = 55

const ZMQ_ROUTER_HANDOVER = 56

const ZMQ_TOS = 57

const ZMQ_CONNECT_ROUTING_ID = 61

const ZMQ_GSSAPI_SERVER = 62

const ZMQ_GSSAPI_PRINCIPAL = 63

const ZMQ_GSSAPI_SERVICE_PRINCIPAL = 64

const ZMQ_GSSAPI_PLAINTEXT = 65

const ZMQ_HANDSHAKE_IVL = 66

const ZMQ_SOCKS_PROXY = 68

const ZMQ_XPUB_NODROP = 69

const ZMQ_BLOCKY = 70

const ZMQ_XPUB_MANUAL = 71

const ZMQ_XPUB_WELCOME_MSG = 72

const ZMQ_STREAM_NOTIFY = 73

const ZMQ_INVERT_MATCHING = 74

const ZMQ_HEARTBEAT_IVL = 75

const ZMQ_HEARTBEAT_TTL = 76

const ZMQ_HEARTBEAT_TIMEOUT = 77

const ZMQ_XPUB_VERBOSER = 78

const ZMQ_CONNECT_TIMEOUT = 79

const ZMQ_TCP_MAXRT = 80

const ZMQ_THREAD_SAFE = 81

const ZMQ_MULTICAST_MAXTPDU = 84

const ZMQ_VMCI_BUFFER_SIZE = 85

const ZMQ_VMCI_BUFFER_MIN_SIZE = 86

const ZMQ_VMCI_BUFFER_MAX_SIZE = 87

const ZMQ_VMCI_CONNECT_TIMEOUT = 88

const ZMQ_USE_FD = 89

const ZMQ_GSSAPI_PRINCIPAL_NAMETYPE = 90

const ZMQ_GSSAPI_SERVICE_PRINCIPAL_NAMETYPE = 91

const ZMQ_BINDTODEVICE = 92

const ZMQ_MORE = 1

const ZMQ_SHARED = 3

const ZMQ_DONTWAIT = 1

const ZMQ_SNDMORE = 2

const ZMQ_NULL = 0

const ZMQ_PLAIN = 1

const ZMQ_CURVE = 2

const ZMQ_GSSAPI = 3

const ZMQ_GROUP_MAX_LENGTH = 255

const ZMQ_IDENTITY = ZMQ_ROUTING_ID

const ZMQ_CONNECT_RID = ZMQ_CONNECT_ROUTING_ID

const ZMQ_TCP_ACCEPT_FILTER = 38

const ZMQ_IPC_FILTER_PID = 58

const ZMQ_IPC_FILTER_UID = 59

const ZMQ_IPC_FILTER_GID = 60

const ZMQ_IPV4ONLY = 31

const ZMQ_DELAY_ATTACH_ON_CONNECT = ZMQ_IMMEDIATE

const ZMQ_NOBLOCK = ZMQ_DONTWAIT

const ZMQ_FAIL_UNROUTABLE = ZMQ_ROUTER_MANDATORY

const ZMQ_ROUTER_BEHAVIOR = ZMQ_ROUTER_MANDATORY

const ZMQ_SRCFD = 2

const ZMQ_GSSAPI_NT_HOSTBASED = 0

const ZMQ_GSSAPI_NT_USER_NAME = 1

const ZMQ_GSSAPI_NT_KRB5_PRINCIPAL = 2

const ZMQ_EVENT_CONNECTED = 0x0001

const ZMQ_EVENT_CONNECT_DELAYED = 0x0002

const ZMQ_EVENT_CONNECT_RETRIED = 0x0004

const ZMQ_EVENT_LISTENING = 0x0008

const ZMQ_EVENT_BIND_FAILED = 0x0010

const ZMQ_EVENT_ACCEPTED = 0x0020

const ZMQ_EVENT_ACCEPT_FAILED = 0x0040

const ZMQ_EVENT_CLOSED = 0x0080

const ZMQ_EVENT_CLOSE_FAILED = 0x0100

const ZMQ_EVENT_DISCONNECTED = 0x0200

const ZMQ_EVENT_MONITOR_STOPPED = 0x0400

const ZMQ_EVENT_ALL = 0xffff

const ZMQ_EVENT_HANDSHAKE_FAILED_NO_DETAIL = 0x0800

const ZMQ_EVENT_HANDSHAKE_SUCCEEDED = 0x1000

const ZMQ_EVENT_HANDSHAKE_FAILED_PROTOCOL = 0x2000

const ZMQ_EVENT_HANDSHAKE_FAILED_AUTH = 0x4000

const ZMQ_PROTOCOL_ERROR_ZMTP_UNSPECIFIED = 0x10000000

const ZMQ_PROTOCOL_ERROR_ZMTP_UNEXPECTED_COMMAND = 0x10000001

const ZMQ_PROTOCOL_ERROR_ZMTP_INVALID_SEQUENCE = 0x10000002

const ZMQ_PROTOCOL_ERROR_ZMTP_KEY_EXCHANGE = 0x10000003

const ZMQ_PROTOCOL_ERROR_ZMTP_MALFORMED_COMMAND_UNSPECIFIED = 0x10000011

const ZMQ_PROTOCOL_ERROR_ZMTP_MALFORMED_COMMAND_MESSAGE = 0x10000012

const ZMQ_PROTOCOL_ERROR_ZMTP_MALFORMED_COMMAND_HELLO = 0x10000013

const ZMQ_PROTOCOL_ERROR_ZMTP_MALFORMED_COMMAND_INITIATE = 0x10000014

const ZMQ_PROTOCOL_ERROR_ZMTP_MALFORMED_COMMAND_ERROR = 0x10000015

const ZMQ_PROTOCOL_ERROR_ZMTP_MALFORMED_COMMAND_READY = 0x10000016

const ZMQ_PROTOCOL_ERROR_ZMTP_MALFORMED_COMMAND_WELCOME = 0x10000017

const ZMQ_PROTOCOL_ERROR_ZMTP_INVALID_METADATA = 0x10000018

const ZMQ_PROTOCOL_ERROR_ZMTP_CRYPTOGRAPHIC = 0x11000001

const ZMQ_PROTOCOL_ERROR_ZMTP_MECHANISM_MISMATCH = 0x11000002

const ZMQ_PROTOCOL_ERROR_ZAP_UNSPECIFIED = 0x20000000

const ZMQ_PROTOCOL_ERROR_ZAP_MALFORMED_REPLY = 0x20000001

const ZMQ_PROTOCOL_ERROR_ZAP_BAD_REQUEST_ID = 0x20000002

const ZMQ_PROTOCOL_ERROR_ZAP_BAD_VERSION = 0x20000003

const ZMQ_PROTOCOL_ERROR_ZAP_INVALID_STATUS_CODE = 0x20000004

const ZMQ_PROTOCOL_ERROR_ZAP_INVALID_METADATA = 0x20000005

const ZMQ_PROTOCOL_ERROR_WS_UNSPECIFIED = 0x30000000

const ZMQ_POLLIN = 1

const ZMQ_POLLOUT = 2

const ZMQ_POLLERR = 4

const ZMQ_POLLPRI = 8

const ZMQ_POLLITEMS_DFLT = 16

const ZMQ_HAS_CAPABILITIES = 1

const ZMQ_STREAMER = 1

const ZMQ_FORWARDER = 2

const ZMQ_QUEUE = 3

end # module
