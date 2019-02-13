# Dispatcher.jl - Adaptive hash-graph persistency mechanism for computational
#                 task graphs written at 0x0α Research by Corneliu Cofaru, 2019

module DispatcherCache

    using DataStructures
    using Dispatcher
    using IterTools
    using JSON
    using TranscodingStreams

    export add_hashes!

    include("constants.jl")
    include("utils.jl")
    include("core.jl")

end # module
