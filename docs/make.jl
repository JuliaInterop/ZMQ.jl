using Documenter, ZMQ
import Changelog

# Build the changelog
Changelog.generate(
    Changelog.Documenter(),
    joinpath(@__DIR__, "src/_changelog.md"),
    joinpath(@__DIR__, "src/changelog.md"),
    repo="JuliaInterop/ZMQ.jl"
)

makedocs(
    modules = [ZMQ],
    sitename="ZMQ.jl",
    authors = "Joel Frederico",
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Guide" => "man/guide.md",
            "man/examples.md",
        ],
        "Reference" => "reference.md",
        "Bindings" => "bindings.md",
        "Changelog" => "changelog.md"
    ],
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true")
)

deploydocs(
    repo = "github.com/JuliaInterop/ZMQ.jl.git",
    target = "build",
)
