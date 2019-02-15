var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Introduction",
    "title": "Introduction",
    "category": "page",
    "text": "CurrentModule=DispatcherCache"
},

{
    "location": "#Introduction-1",
    "page": "Introduction",
    "title": "Introduction",
    "category": "section",
    "text": "DispatcherCache is a task persistency mechanism for Dispatcher.jl computational task graphs. It is based on graphchain."
},

{
    "location": "#Installation-1",
    "page": "Introduction",
    "title": "Installation",
    "category": "section",
    "text": "In the shell of choice, using$ git clone https://github.com/zgornel/DispatcherCache.jlor, inside Julia] add https://github.com/zgornel/DispatcherCache.jl#master"
},

{
    "location": "examples/#",
    "page": "Usage examples",
    "title": "Usage examples",
    "category": "page",
    "text": ""
},

{
    "location": "examples/#Usage-examples-1",
    "page": "Usage examples",
    "title": "Usage examples",
    "category": "section",
    "text": "To do ..."
},

{
    "location": "api/#DispatcherCache.DispatcherCache",
    "page": "API Reference",
    "title": "DispatcherCache.DispatcherCache",
    "category": "module",
    "text": "DispatcherCache.jl is a hash-chain optimizer for Dispatcher delayed execution graphs. It employes a hashing mechanism to check wether the state associated to a node is the DispatchGraph  that is to be executed has already been hashed (and hence, an output is available) or, it is new or changed. Depending on the current state (by \'state\' one understands the called function source code, input arguments and other input node dependencies), the current task becomes a load-from-disk or an execute-and-store-to-disk operation. This is done is such a manner that the minimimum number of load/execute operations are performed, minimizing both persistency and computational demands.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.cache!-Union{Tuple{DispatchGraph}, Tuple{T}, Tuple{DispatchGraph,Array{T,1}}, Tuple{DispatchGraph,Array{T,1},Array{T,1}}} where T<:(Union{#s114, #s115} where #s115<:AbstractString where #s114<:Dispatcher.DispatchNode)",
    "page": "API Reference",
    "title": "DispatcherCache.cache!",
    "category": "method",
    "text": "cache!(graph, endpoints, uncacheable, compression=DEFAULT_COMPRESSION, cachedir=DEFAULT_CACHE_DIR)\n\nOptimizes a delayed execution graph graph::DispatchGraph by wrapping individual nodes in load-from-disk on execute-and-store wrappers depending on the state of the disk cache and of the graph. The function modifies inplace the input graph and should be called on the same unmodified graph after each execution and not on the modified graph.\n\nOnce the original graph is modified, calling run! on it will, if the cache is already present, load the top most consistent key or alternatively re-run and store the outputs of nodes which have new state.\n\nArguments\n\ngraph::DispatchGraph input graph\nendpoints::Vector{Union{DispatchNode, AbstractString}} top nodes for which\n\ncaching will occur; nodes that depend on these will not be cached. The nodes can be specified either by label of by the node object itself\n\nuncacheable::Vector{Union{DispatchNode, AbstractString}}` nodes that will\n\nnever be cached and will always be executed (these nodes are still hashed and their hashes influence upstream node hashes as well)\n\nKeyword arguments\n\ncompression::String enables compression of the node outputs.\n\nAvailable options are \"none\", for no compression, \"bz2\" or \"bzip2\" for BZIP compression and \"gz\" or \"gzip\" for GZIP compression\n\ncachedir::String The cache directory.\n\nExamples\n\njulia> # TODO ...\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.__hash-Tuple{Any}",
    "page": "API Reference",
    "title": "DispatcherCache.__hash",
    "category": "method",
    "text": "__hash(something)\n\nReturn a hexadecimal string corresponding to the hash of sum of the hashes of the value and type of something.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_arguments_hash-Tuple{Dispatcher.Op}",
    "page": "API Reference",
    "title": "DispatcherCache.get_arguments_hash",
    "category": "method",
    "text": "get_arguments_hash(node)\n\nHash the data arguments (in certain cases configuration fields) of the dispatch node.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_compressor-Tuple{AbstractString,AbstractString}",
    "page": "API Reference",
    "title": "DispatcherCache.get_compressor",
    "category": "method",
    "text": "get_compressor(compression, action)\n\nReturn a TranscodingStreams compatible compressor or decompressor based on the values of compression and action.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_dependencies_hash-Tuple{Dispatcher.DispatchNode,Any}",
    "page": "API Reference",
    "title": "DispatcherCache.get_dependencies_hash",
    "category": "method",
    "text": "get_dependencies_hash(node, keyhashmaps)\n\nHash the dispatch node dependencies of node using their existing hashes if possible.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_hash-Union{Tuple{T}, Tuple{DispatchNode,Dict{T,String}}} where T",
    "page": "API Reference",
    "title": "DispatcherCache.get_hash",
    "category": "method",
    "text": "get_hash(node, keyhashmaps)\n\nCalculates and returns the hash corresponding to a Dispatcher task graph node i.e. DispatchNode using the hashes of its dependencies, input arguments and source code of the function associated to the node. Any available hashes are taken from keyhashmap.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_source_hash-Tuple{Dispatcher.Op}",
    "page": "API Reference",
    "title": "DispatcherCache.get_source_hash",
    "category": "method",
    "text": "get_source_hash(node)\n\nHashes the lowered representation of the source code of the function associated with node. Useful for Op nodes, the other node types do not have any associated source code.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.input_nodes-Tuple{Dispatcher.DispatchGraph}",
    "page": "API Reference",
    "title": "DispatcherCache.input_nodes",
    "category": "method",
    "text": "input_nodes(graph::DispatchGraph) ->\n\nReturn an iterable of all nodes in the graph with no input edges.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.load_hashchain",
    "page": "API Reference",
    "title": "DispatcherCache.load_hashchain",
    "category": "function",
    "text": "load_hashchain(cachedir [; compression=DEFAULT_COMPRESSION])\n\nLoads the hashchain file found in the directory cachedir. Before loading, the compression value is checked against the one stored in the hashchain file (both have to match). If the file does not exist, it is created.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.store_hashchain",
    "page": "API Reference",
    "title": "DispatcherCache.store_hashchain",
    "category": "function",
    "text": "store_hashchain(hashchain, cachedir=DEFAULT_CACHE_DIR [; compression=DEFAULT_COMPRESSION, version=1])\n\nStores the hashchain object in a file named DEFAULT_HASHCHAIN_FILENAME, in the directory cachedir. The values of compression and version are stored as well in the file.\n\n\n\n\n\n"
},

{
    "location": "api/#",
    "page": "API Reference",
    "title": "API Reference",
    "category": "page",
    "text": "Modules = [DispatcherCache]"
},

]}
