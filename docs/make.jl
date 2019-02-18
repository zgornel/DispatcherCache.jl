using Pkg
Pkg.add("Documenter")
Pkg.add("Dispatcher")
using Documenter, Dispatcher, DispatcherCache

# Make src directory available
push!(LOAD_PATH,"../src/")

# Make documentation
makedocs(
    modules = [DispatcherCache],
    format = :html,
    sitename = "DispatcherCache.jl",
    authors = "Corneliu Cofaru, 0x0α Research",
    clean = true,
    debug = true,
    pages = [
        "Introduction" => "index.md",
        "Usage examples" => "examples.md",
        "API Reference" => "api.md",
    ]
)

# Deploy documentation
deploydocs(
    repo = "github.com/zgornel/DispatcherCache.jl.git",
    target = "build",
    deps = nothing,
    make = nothing
)
