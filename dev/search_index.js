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
    "location": "api/#DispatcherCache.__hash-Tuple{Any}",
    "page": "API Reference",
    "title": "DispatcherCache.__hash",
    "category": "method",
    "text": "__hash(something)\n\nReturn a hexadecimal string corresponding to the hash of sum of the hashes of the value and type of something.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_compressor-Tuple{AbstractString,AbstractString}",
    "page": "API Reference",
    "title": "DispatcherCache.get_compressor",
    "category": "method",
    "text": "get_compressor(compression, action)\n\nReturn a TranscodingStreams compatible compressor or decompressor based on the values of compression and action.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_hash-Union{Tuple{T}, Tuple{DispatchNode,Dict{T,String}}} where T",
    "page": "API Reference",
    "title": "DispatcherCache.get_hash",
    "category": "method",
    "text": "get_hash(node, keyhashmaps)\n\nCalculates and returns the hash corresponding to a Dispatcher task graph node i.e. DispatchNode using the hashes of its dependencies, input arguments and source code of the function associated to the node. Any available hashes are taken from keyhashmap.\n\n\n\n\n\n"
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
