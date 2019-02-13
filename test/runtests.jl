using Test
using DispatcherCache
using Dispatcher
using Memento

# Set Dispatcher logging level to warning
setlevel!(getlogger("Dispatcher"), "warn")

# Run tests
include("core.jl")
