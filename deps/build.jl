using BinDeps
using Compat

@BinDeps.setup

function validate(name, handle)
    try
        fhandle = Libdl.dlsym(handle, :zmq_version)
        major = Vector{Cint}(1)
        minor = Vector{Cint}(1)
        patch = Vector{Cint}(1)
        ccall(fhandle, Void, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major, minor, patch)
        return VersionNumber(major[1], minor[1], patch[1]) >= v"3"
    catch
        return false
    end
end

zmq = library_dependency("zmq", aliases = ["libzmq", "libzmq.so.3"], validate = validate)

provides(Sources, URI("https://archive.org/download/zeromq_3.2.4/zeromq-3.2.4.tar.gz"), zmq)
provides(BuildProcess, Autotools(libtarget = "src/.libs/libzmq." * BinDeps.shlib_ext), zmq)

provides(AptGet, "libzmq3", zmq, os = :Linux)
provides(Yum, "czmq-devel", zmq, os = :Linux)

if is_windows()
    using WinRPM
    provides(WinRPM.RPM, "zeromq", [zmq], os = :Windows)
elseif is_apple()
    using Homebrew
    provides(Homebrew.HB, "staticfloat/juliadeps/zeromq32", zmq, os = :Darwin)
end

@BinDeps.install Dict(:zmq => :zmq)
