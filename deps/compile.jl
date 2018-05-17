using BinaryProvider, Compat
using Compat.Libdl: dlext

function compile(libname, tarball_url, hash; prefix=BinaryProvider.global_prefix, verbose=false)
    # download to tarball_path
    tarball_path = joinpath(prefix, "downloads", basename(tarball_url))
    download_verify(tarball_url, hash, tarball_path; force=true, verbose=verbose)

    # unpack into source_path
    tarball_dir = joinpath(prefix, "downloads", split(first(list_tarball_files(tarball_path)), '/')[1]) # e.g. "zeromq-4.2.5"
    source_path = joinpath(prefix, "downloads", "src")
    verbose && Compat.@info("Unpacking $tarball_path into $source_path")
    rm(tarball_dir, force=true, recursive=true)
    rm(source_path, force=true, recursive=true)
    unpack(tarball_path, dirname(tarball_dir); verbose=verbose)
    mv(tarball_dir, source_path)

    install_dir = joinpath(source_path, "julia_install")
    verbose && Compat.@info("Compiling in $source_path...")
    cd(source_path) do
        run(`./configure --prefix=$install_dir --without-docs --disable-libunwind --disable-perf --disable-eventfd --without-gcov --disable-curve-keygen`)
        run(`make`)
        run(`make install`)
        mkpath(libdir(prefix))
        cp("$install_dir/lib/libzmq.$dlext", joinpath(libdir(prefix), libname*"."*dlext),
           remove_destination=true, follow_symlinks=true)
    end
end
