# Dispatcher.jl - Adaptive hash-graph persistency mechanism for computational
#                 task graphs written at 0x0α Research by Corneliu Cofaru, 2019

"""
DispatcherCache.jl is a `hash-chain` optimizer for Dispatcher delayed
execution graphs. It employes a hashing mechanism to check wether the
state associated to a node is the `DispatchGraph`  that is to
be executed has already been `hashed` (and hence, an output is available)
or, it is new or changed. Depending on the current state (by 'state'
one understands the called function source code, input arguments and
other input node dependencies), the current task becomes a load-from-disk
or an execute-and-store-to-disk operation. This is done is such a manner that
the minimimum number of load/execute operations are performed, minimizing
both persistency and computational demands.
"""
module DispatcherCache

    using Serialization
    using Dispatcher
    using IterTools
    using JSON
    using TranscodingStreams
    using CodecBzip2
    using CodecZlib

    import Dispatcher: run!
    export add_hash_cache!

    include("constants.jl")
    include("utils.jl")
    include("wrappers.jl")
    include("hash.jl")
    include("core.jl")

end # module
