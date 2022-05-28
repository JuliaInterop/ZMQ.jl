using Documenter, ZMQ

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
    ],
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true")
)

deploydocs(
    repo = "github.com/JuliaInterop/ZMQ.jl.git",
    target = "build",
)
