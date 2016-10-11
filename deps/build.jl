using BinDeps
using Compat

@BinDeps.setup

function validate(name, handle)
    try
        fhandle = dlsym(handle, :zmq_version)
        major = Array(Cint,1)
        minor = Array(Cint,1)
        patch = Array(Cint,1)
        ccall(fhandle, Void, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major, minor, patch)
        global const version = VersionNumber(major[1], minor[1], patch[1])
        return version >= v"3"
    catch
        return false
    end
end

zmq = library_dependency("zmq", aliases = ["libzmq"], validate=validate)

provides(AptGet,"libzmq3-dev",zmq)

provides(Sources,URI("https://archive.org/download/zeromq_3.2.4/zeromq-3.2.4.tar.gz"),zmq)
provides(BuildProcess,Autotools(libtarget = "src/.libs/libzmq."*BinDeps.shlib_ext),zmq)

if is_windows()
    using WinRPM
    provides(WinRPM.RPM, "zeromq", [zmq], os = :Windows)
end

if is_apple()
    if Pkg.installed("Homebrew") === nothing
        error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")  end
    using Homebrew
    provides( Homebrew.HB, "staticfloat/juliadeps/zeromq32", zmq, os = :Darwin )
end

@BinDeps.install @compat Dict(:zmq => :zmq)
