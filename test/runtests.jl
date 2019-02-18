using Test
using Dispatcher
using Memento
using TranscodingStreams
using CodecBzip2
using CodecZlib
using JSON
using DispatcherCache

# Set Dispatcher logging level to warning
setlevel!(getlogger("Dispatcher"), "warn")

# Run tests
# TODO(Corneliu) Low level tests for the hashing and utils functions
include("compression.jl")
include("core.jl")
