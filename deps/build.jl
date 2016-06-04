using BinDeps
using Compat

@BinDeps.setup

zmq = library_dependency("zmq", aliases = ["libzmq"])

provides(Sources,URI("https://archive.org/download/zeromq_3.2.4/zeromq-3.2.4.tar.gz"),zmq)
provides(BuildProcess,Autotools(libtarget = "src/.libs/libzmq."*BinDeps.shlib_ext),zmq)

@windows_only begin
    using WinRPM
    provides(WinRPM.RPM, "zeromq", [zmq], os = :Windows)
end

@osx_only begin
    if Pkg.installed("Homebrew") === nothing
        error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")  end
    using Homebrew
    provides( Homebrew.HB, "zeromq32", zmq, os = :Darwin )
end

@BinDeps.install @compat Dict(:zmq => :zmq)
