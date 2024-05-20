module lib

import ZeroMQ_jll: libzmq


function zmq_errno()
    @ccall libzmq.zmq_errno()::Cint
end

function zmq_strerror(errnum_)
    @ccall libzmq.zmq_strerror(errnum_::Cint)::Ptr{Cchar}
end

function zmq_version(major_, minor_, patch_)
    @ccall libzmq.zmq_version(major_::Ptr{Cint}, minor_::Ptr{Cint}, patch_::Ptr{Cint})::Cvoid
end

function zmq_ctx_new()
    @ccall libzmq.zmq_ctx_new()::Ptr{Cvoid}
end

function zmq_ctx_term(context_)
    @ccall libzmq.zmq_ctx_term(context_::Ptr{Cvoid})::Cint
end

function zmq_ctx_shutdown(context_)
    @ccall libzmq.zmq_ctx_shutdown(context_::Ptr{Cvoid})::Cint
end

function zmq_ctx_set(context_, option_, optval_)
    @ccall libzmq.zmq_ctx_set(context_::Ptr{Cvoid}, option_::Cint, optval_::Cint)::Cint
end

function zmq_ctx_get(context_, option_)
    @ccall libzmq.zmq_ctx_get(context_::Ptr{Cvoid}, option_::Cint)::Cint
end

function zmq_init(io_threads_)
    @ccall libzmq.zmq_init(io_threads_::Cint)::Ptr{Cvoid}
end

function zmq_term(context_)
    @ccall libzmq.zmq_term(context_::Ptr{Cvoid})::Cint
end

function zmq_ctx_destroy(context_)
    @ccall libzmq.zmq_ctx_destroy(context_::Ptr{Cvoid})::Cint
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

function zmq_msg_init(msg_)
    @ccall libzmq.zmq_msg_init(msg_::Ptr{zmq_msg_t})::Cint
end

function zmq_msg_init_size(msg_, size_)
    @ccall libzmq.zmq_msg_init_size(msg_::Ptr{zmq_msg_t}, size_::Csize_t)::Cint
end

function zmq_msg_init_data(msg_, data_, size_, ffn_, hint_)
    @ccall libzmq.zmq_msg_init_data(msg_::Ptr{zmq_msg_t}, data_::Ptr{Cvoid}, size_::Csize_t, ffn_::Ptr{zmq_free_fn}, hint_::Ptr{Cvoid})::Cint
end

function zmq_msg_send(msg_, s_, flags_)
    @ccall libzmq.zmq_msg_send(msg_::Ptr{zmq_msg_t}, s_::Ptr{Cvoid}, flags_::Cint)::Cint
end

function zmq_msg_recv(msg_, s_, flags_)
    @ccall libzmq.zmq_msg_recv(msg_::Ptr{zmq_msg_t}, s_::Ptr{Cvoid}, flags_::Cint)::Cint
end

function zmq_msg_close(msg_)
    @ccall libzmq.zmq_msg_close(msg_::Ptr{zmq_msg_t})::Cint
end

function zmq_msg_move(dest_, src_)
    @ccall libzmq.zmq_msg_move(dest_::Ptr{zmq_msg_t}, src_::Ptr{zmq_msg_t})::Cint
end

function zmq_msg_copy(dest_, src_)
    @ccall libzmq.zmq_msg_copy(dest_::Ptr{zmq_msg_t}, src_::Ptr{zmq_msg_t})::Cint
end

function zmq_msg_data(msg_)
    @ccall libzmq.zmq_msg_data(msg_::Ptr{zmq_msg_t})::Ptr{Cvoid}
end

function zmq_msg_size(msg_)
    @ccall libzmq.zmq_msg_size(msg_::Ptr{zmq_msg_t})::Csize_t
end

function zmq_msg_more(msg_)
    @ccall libzmq.zmq_msg_more(msg_::Ptr{zmq_msg_t})::Cint
end

function zmq_msg_get(msg_, property_)
    @ccall libzmq.zmq_msg_get(msg_::Ptr{zmq_msg_t}, property_::Cint)::Cint
end

function zmq_msg_set(msg_, property_, optval_)
    @ccall libzmq.zmq_msg_set(msg_::Ptr{zmq_msg_t}, property_::Cint, optval_::Cint)::Cint
end

function zmq_msg_gets(msg_, property_)
    @ccall libzmq.zmq_msg_gets(msg_::Ptr{zmq_msg_t}, property_::Ptr{Cchar})::Ptr{Cchar}
end

function zmq_socket(arg1, type_)
    @ccall libzmq.zmq_socket(arg1::Ptr{Cvoid}, type_::Cint)::Ptr{Cvoid}
end

function zmq_close(s_)
    @ccall libzmq.zmq_close(s_::Ptr{Cvoid})::Cint
end

function zmq_setsockopt(s_, option_, optval_, optvallen_)
    @ccall libzmq.zmq_setsockopt(s_::Ptr{Cvoid}, option_::Cint, optval_::Ptr{Cvoid}, optvallen_::Csize_t)::Cint
end

function zmq_getsockopt(s_, option_, optval_, optvallen_)
    @ccall libzmq.zmq_getsockopt(s_::Ptr{Cvoid}, option_::Cint, optval_::Ptr{Cvoid}, optvallen_::Ptr{Csize_t})::Cint
end

function zmq_bind(s_, addr_)
    @ccall libzmq.zmq_bind(s_::Ptr{Cvoid}, addr_::Ptr{Cchar})::Cint
end

function zmq_connect(s_, addr_)
    @ccall libzmq.zmq_connect(s_::Ptr{Cvoid}, addr_::Ptr{Cchar})::Cint
end

function zmq_unbind(s_, addr_)
    @ccall libzmq.zmq_unbind(s_::Ptr{Cvoid}, addr_::Ptr{Cchar})::Cint
end

function zmq_disconnect(s_, addr_)
    @ccall libzmq.zmq_disconnect(s_::Ptr{Cvoid}, addr_::Ptr{Cchar})::Cint
end

function zmq_send(s_, buf_, len_, flags_)
    @ccall libzmq.zmq_send(s_::Ptr{Cvoid}, buf_::Ptr{Cvoid}, len_::Csize_t, flags_::Cint)::Cint
end

function zmq_send_const(s_, buf_, len_, flags_)
    @ccall libzmq.zmq_send_const(s_::Ptr{Cvoid}, buf_::Ptr{Cvoid}, len_::Csize_t, flags_::Cint)::Cint
end

function zmq_recv(s_, buf_, len_, flags_)
    @ccall libzmq.zmq_recv(s_::Ptr{Cvoid}, buf_::Ptr{Cvoid}, len_::Csize_t, flags_::Cint)::Cint
end

function zmq_socket_monitor(s_, addr_, events_)
    @ccall libzmq.zmq_socket_monitor(s_::Ptr{Cvoid}, addr_::Ptr{Cchar}, events_::Cint)::Cint
end

const zmq_fd_t = Cint

mutable struct zmq_pollitem_t
    socket::Ptr{Cvoid}
    fd::zmq_fd_t
    events::Cshort
    revents::Cshort
end

function zmq_poll(items_, nitems_, timeout_)
    @ccall libzmq.zmq_poll(items_::Ptr{zmq_pollitem_t}, nitems_::Cint, timeout_::Clong)::Cint
end

function zmq_proxy(frontend_, backend_, capture_)
    @ccall libzmq.zmq_proxy(frontend_::Ptr{Cvoid}, backend_::Ptr{Cvoid}, capture_::Ptr{Cvoid})::Cint
end

function zmq_proxy_steerable(frontend_, backend_, capture_, control_)
    @ccall libzmq.zmq_proxy_steerable(frontend_::Ptr{Cvoid}, backend_::Ptr{Cvoid}, capture_::Ptr{Cvoid}, control_::Ptr{Cvoid})::Cint
end

function zmq_has(capability_)
    @ccall libzmq.zmq_has(capability_::Ptr{Cchar})::Cint
end

function zmq_device(type_, frontend_, backend_)
    @ccall libzmq.zmq_device(type_::Cint, frontend_::Ptr{Cvoid}, backend_::Ptr{Cvoid})::Cint
end

function zmq_sendmsg(s_, msg_, flags_)
    @ccall libzmq.zmq_sendmsg(s_::Ptr{Cvoid}, msg_::Ptr{zmq_msg_t}, flags_::Cint)::Cint
end

function zmq_recvmsg(s_, msg_, flags_)
    @ccall libzmq.zmq_recvmsg(s_::Ptr{Cvoid}, msg_::Ptr{zmq_msg_t}, flags_::Cint)::Cint
end

mutable struct iovec end

function zmq_sendiov(s_, iov_, count_, flags_)
    @ccall libzmq.zmq_sendiov(s_::Ptr{Cvoid}, iov_::Ptr{iovec}, count_::Csize_t, flags_::Cint)::Cint
end

function zmq_recviov(s_, iov_, count_, flags_)
    @ccall libzmq.zmq_recviov(s_::Ptr{Cvoid}, iov_::Ptr{iovec}, count_::Ptr{Csize_t}, flags_::Cint)::Cint
end

function zmq_z85_encode(dest_, data_, size_)
    @ccall libzmq.zmq_z85_encode(dest_::Ptr{Cchar}, data_::Ptr{UInt8}, size_::Csize_t)::Ptr{Cchar}
end

function zmq_z85_decode(dest_, string_)
    @ccall libzmq.zmq_z85_decode(dest_::Ptr{UInt8}, string_::Ptr{Cchar})::Ptr{UInt8}
end

function zmq_curve_keypair(z85_public_key_, z85_secret_key_)
    @ccall libzmq.zmq_curve_keypair(z85_public_key_::Ptr{Cchar}, z85_secret_key_::Ptr{Cchar})::Cint
end

function zmq_curve_public(z85_public_key_, z85_secret_key_)
    @ccall libzmq.zmq_curve_public(z85_public_key_::Ptr{Cchar}, z85_secret_key_::Ptr{Cchar})::Cint
end

function zmq_atomic_counter_new()
    @ccall libzmq.zmq_atomic_counter_new()::Ptr{Cvoid}
end

function zmq_atomic_counter_set(counter_, value_)
    @ccall libzmq.zmq_atomic_counter_set(counter_::Ptr{Cvoid}, value_::Cint)::Cvoid
end

function zmq_atomic_counter_inc(counter_)
    @ccall libzmq.zmq_atomic_counter_inc(counter_::Ptr{Cvoid})::Cint
end

function zmq_atomic_counter_dec(counter_)
    @ccall libzmq.zmq_atomic_counter_dec(counter_::Ptr{Cvoid})::Cint
end

function zmq_atomic_counter_value(counter_)
    @ccall libzmq.zmq_atomic_counter_value(counter_::Ptr{Cvoid})::Cint
end

function zmq_atomic_counter_destroy(counter_p_)
    @ccall libzmq.zmq_atomic_counter_destroy(counter_p_::Ptr{Ptr{Cvoid}})::Cvoid
end

# typedef void ( zmq_timer_fn ) ( int timer_id , void * arg )
const zmq_timer_fn = Cvoid

function zmq_timers_new()
    @ccall libzmq.zmq_timers_new()::Ptr{Cvoid}
end

function zmq_timers_destroy(timers_p)
    @ccall libzmq.zmq_timers_destroy(timers_p::Ptr{Ptr{Cvoid}})::Cint
end

function zmq_timers_add(timers, interval, handler, arg)
    @ccall libzmq.zmq_timers_add(timers::Ptr{Cvoid}, interval::Csize_t, handler::zmq_timer_fn, arg::Ptr{Cvoid})::Cint
end

function zmq_timers_cancel(timers, timer_id)
    @ccall libzmq.zmq_timers_cancel(timers::Ptr{Cvoid}, timer_id::Cint)::Cint
end

function zmq_timers_set_interval(timers, timer_id, interval)
    @ccall libzmq.zmq_timers_set_interval(timers::Ptr{Cvoid}, timer_id::Cint, interval::Csize_t)::Cint
end

function zmq_timers_reset(timers, timer_id)
    @ccall libzmq.zmq_timers_reset(timers::Ptr{Cvoid}, timer_id::Cint)::Cint
end

function zmq_timers_timeout(timers)
    @ccall libzmq.zmq_timers_timeout(timers::Ptr{Cvoid})::Clong
end

function zmq_timers_execute(timers)
    @ccall libzmq.zmq_timers_execute(timers::Ptr{Cvoid})::Cint
end

function zmq_stopwatch_start()
    @ccall libzmq.zmq_stopwatch_start()::Ptr{Cvoid}
end

function zmq_stopwatch_intermediate(watch_)
    @ccall libzmq.zmq_stopwatch_intermediate(watch_::Ptr{Cvoid})::Culong
end

function zmq_stopwatch_stop(watch_)
    @ccall libzmq.zmq_stopwatch_stop(watch_::Ptr{Cvoid})::Culong
end

function zmq_sleep(seconds_)
    @ccall libzmq.zmq_sleep(seconds_::Cint)::Cvoid
end

# typedef void ( zmq_thread_fn ) ( void * )
const zmq_thread_fn = Cvoid

function zmq_threadstart(func_, arg_)
    @ccall libzmq.zmq_threadstart(func_::Ptr{zmq_thread_fn}, arg_::Ptr{Cvoid})::Ptr{Cvoid}
end

function zmq_threadclose(thread_)
    @ccall libzmq.zmq_threadclose(thread_::Ptr{Cvoid})::Cvoid
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
