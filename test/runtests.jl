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
include("compression.jl")
include("hash.jl")
include("core.jl")
