using BinaryProvider # requires BinaryProvider 0.3.0 or later

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, String["libzmq"], :libzmq),
]

# Download binaries from hosted location
bin_prefix = "https://github.com/JuliaInterop/ZMQBuilder/releases/download/v4.2.5+5"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, :glibc) => ("$bin_prefix/ZMQ.aarch64-linux-gnu.tar.gz", "cca0f7ceebc5c517794af63d26b307c16b6e215eb978b95543314851747db759"),
    Linux(:aarch64, :musl) => ("$bin_prefix/ZMQ.aarch64-linux-musl.tar.gz", "bb44f9e7351be07f6dffc4b5c1eef69cdfb65843f44949366c4a64aa011e5a04"),
    Linux(:armv7l, :glibc, :eabihf) => ("$bin_prefix/ZMQ.arm-linux-gnueabihf.tar.gz", "9b458ebe9272fe00ba4c476aacfd63234e4cb1f1e8170f22379b98026c42d62f"),
    Linux(:armv7l, :musl, :eabihf) => ("$bin_prefix/ZMQ.arm-linux-musleabihf.tar.gz", "1ebe76ccd9c5c56e938d0cca28639fa5f968a2be69e1ab82510de4a71f34d3aa"),
    Linux(:i686, :glibc) => ("$bin_prefix/ZMQ.i686-linux-gnu.tar.gz", "bddf00cac999ce9d53585995570fe82213f8d75d7c459a6b0db6a388b67b4d66"),
    Linux(:i686, :musl) => ("$bin_prefix/ZMQ.i686-linux-musl.tar.gz", "6172d284ca92c7e304d1ab2b234b653fcb825a02d30647021ee4841338358d96"),
    Windows(:i686) => ("$bin_prefix/ZMQ.i686-w64-mingw32.tar.gz", "8e731083e8468126fc657977ea86a99fe332e2f47c2aefdf50146a838f742caa"),
    Linux(:powerpc64le, :glibc) => ("$bin_prefix/ZMQ.powerpc64le-linux-gnu.tar.gz", "2a9a315706a7ddb1d0cd9e365a6bd132922749f2990e8ab04b1f67d54969e92f"),
    MacOS(:x86_64) => ("$bin_prefix/ZMQ.x86_64-apple-darwin14.tar.gz", "0a649b33d609486d748f5c33c43460b089e876e88030e3293c49d17952f4c8d2"),
    Linux(:x86_64, :glibc) => ("$bin_prefix/ZMQ.x86_64-linux-gnu.tar.gz", "a4ebe3d86a6f1cff715ae398a87e14aaf5058607c70be00f14e7cae6648994c9"),
    Linux(:x86_64, :musl) => ("$bin_prefix/ZMQ.x86_64-linux-musl.tar.gz", "7c0d1fe70e49370ef6ed3ae8c7b70a82ada6c80c029966f4f717957604592b71"),
    Windows(:x86_64) => ("$bin_prefix/ZMQ.x86_64-w64-mingw32.tar.gz", "84f8937f65015620ec56cb1ee867217edcfb6b2aec7ea41a2b1d9c32fe616925"),
)

# Install unsatisfied or updated dependencies:
unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
if haskey(download_info, platform_key())
    url, tarball_hash = download_info[platform_key()]
    if unsatisfied || !isinstalled(url, tarball_hash; prefix=prefix)
        # Download and install binaries
        install(url, tarball_hash; prefix=prefix, force=true, verbose=verbose)
    end
elseif unsatisfied
    # If we don't have a BinaryProvider-compatible .tar.gz to download, complain.
    # Alternatively, you could attempt to install from a separate provider,
    # build from source or something even more ambitious here.
    error("Your platform $(triplet(platform_key())) is not supported by this package!")
end

# Write out a deps.jl file that will contain mappings for our products
write_deps_file(joinpath(@__DIR__, "deps.jl"), products)
