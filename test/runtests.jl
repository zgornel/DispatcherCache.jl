using Test
using Dispatcher
using Memento
using DispatcherCache

# Set Dispatcher logging level to warning
setlevel!(getlogger("Dispatcher"), "warn")

# Run tests
include("core.jl")
