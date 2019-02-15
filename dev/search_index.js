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
    "location": "api/#Dispatcher.run!-Union{Tuple{T}, Tuple{Executor,DispatchGraph,Array{T,1}}, Tuple{Executor,DispatchGraph,Array{T,1},Array{T,1}}} where T<:(Union{#s111, #s98} where #s98<:AbstractString where #s111<:Dispatcher.DispatchNode)",
    "page": "API Reference",
    "title": "Dispatcher.run!",
    "category": "method",
    "text": "run!(exec, graph, endpoints, uncacheable=[]\n     [;compression=DEFAULT_COMPRESSION, cachedir=DEFAULT_CACHE_DIR])\n\nRuns the graph::DispatchGraph and loads or executes and stores the outputs of the nodes in the subgraph whose leaf nodes are given by endpoints. Nodes in uncachable are not locally cached.\n\nArguments\n\nexec::Executor the Dispatcher.jl executor\ngraph::DispatchGraph input dispatch graph\nendpoints::Vector{Union{DispatchNode, AbstractString}} leaf nodes for which\n\ncaching will occur; nodes that depend on these will not be cached. The nodes can be specified either by label of by the node object itself\n\nuncacheable::Vector{Union{DispatchNode, AbstractString}}` nodes that will\n\nnever be cached and will always be executed (these nodes are still hashed and their hashes influence upstream node hashes as well)\n\nKeyword arguments\n\ncompression::String enables compression of the node outputs.\n\nAvailable options are \"none\", for no compression, \"bz2\" or \"bzip2\" for BZIP compression and \"gz\" or \"gzip\" for GZIP compression\n\ncachedir::String The cache directory.\n\nExamples\n\njulia> using Dispatcher\n       using DispatcherCache\n\n       # Some functions\n       foo(x) = begin sleep(1); x end\n       bar(x) = begin sleep(1); x+1 end\n       baz(x,y) = begin sleep(1); x-y end\n\n       # Make a dispatch graph out of some operations\n       op1 = @op foo(1)\n       op2 = @op bar(2)\n       op3 = @op baz(op1, op2)\n       D = DispatchGraph(op3)\nDispatchGraph({3, 2} directed simple Int64 graph,\nNodeSet(DispatchNode[\nOp(DeferredFuture at (1,1,241),baz,\"baz\"),\nOp(DeferredFuture at (1,1,239),foo,\"foo\"),\nOp(DeferredFuture at (1,1,240),bar,\"bar\")]))\n\njulia> # First run, writes results to disk (lasts 2 seconds)\n       result_node = [op3]  # the node for which we want results\n       cachedir = \"./__cache__\"  # directory does not exist\n       @time r = run!(AsyncExecutor(), D,\n                      result_node, cachedir=cachedir)\n       println(\"result (first run) = $(fetch(r[1].result.value))\")\n[info | Dispatcher]: Executing 3 graph nodes.\n[info | Dispatcher]: Node 1 (Op<baz, Op<foo>, Op<bar>>): running.\n[info | Dispatcher]: Node 2 (Op<foo, Int64>): running.\n[info | Dispatcher]: Node 3 (Op<bar, Int64>): running.\n[info | Dispatcher]: Node 2 (Op<foo, Int64>): complete.\n[info | Dispatcher]: Node 3 (Op<bar, Int64>): complete.\n[info | Dispatcher]: Node 1 (Op<baz, Op<foo>, Op<bar>>): complete.\n[info | Dispatcher]: All 3 nodes executed.\n  2.029992 seconds (11.53 k allocations: 1.534 MiB)\nresult (first run) = -2\n\njulia> # Secod run, loads directly the result from ./__cachedir__\n       @time r = run!(AsyncExecutor(), D,\n                      [op3], cachedir=cachedir)\n       println(\"result (second run) = $(fetch(r[1].result.value))\")\n[info | Dispatcher]: Executing 1 graph nodes.\n[info | Dispatcher]: Node 1 (Op<baz>): running.\n[info | Dispatcher]: Node 1 (Op<baz>): complete.\n[info | Dispatcher]: All 1 nodes executed.\n  0.005257 seconds (2.57 k allocations: 478.359 KiB)\nresult (second run) = -2\n\njulia> readdir(cachedir)\n2-element Array{String,1}:\n \"cache\"\n \"hashchain.json\"\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.__hash-Tuple{Any}",
    "page": "API Reference",
    "title": "DispatcherCache.__hash",
    "category": "method",
    "text": "__hash(something)\n\nReturn a hexadecimal string corresponding to the hash of sum of the hashes of the value and type of something.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.cache!-Union{Tuple{DispatchGraph}, Tuple{T}, Tuple{DispatchGraph,Array{T,1}}, Tuple{DispatchGraph,Array{T,1},Array{T,1}}} where T<:(Union{#s115, #s116} where #s116<:AbstractString where #s115<:Dispatcher.DispatchNode)",
    "page": "API Reference",
    "title": "DispatcherCache.cache!",
    "category": "method",
    "text": "cache!(graph, endpoints, uncacheable, compression=DEFAULT_COMPRESSION, cachedir=DEFAULT_CACHE_DIR)\n\nOptimizes a delayed execution graph graph::DispatchGraph by wrapping individual nodes in load-from-disk on execute-and-store wrappers depending on the state of the disk cache and of the graph. The function modifies inplace the input graph and should be called on the same unmodified graph after each execution and not on the modified graph.\n\nOnce the original graph is modified, calling run! on it will, if the cache is already present, load the top most consistent key or alternatively re-run and store the outputs of nodes which have new state.\n\nArguments\n\nexec::Executor the Dispatcher.jl executor\ngraph::DispatchGraph input dispatch graph\nendpoints::Vector{Union{DispatchNode, AbstractString}} leaf nodes for which\n\ncaching will occur; nodes that depend on these will not be cached. The nodes can be specified either by label of by the node object itself\n\nuncacheable::Vector{Union{DispatchNode, AbstractString}}` nodes that will\n\nnever be cached and will always be executed (these nodes are still hashed and their hashes influence upstream node hashes as well)\n\nKeyword arguments\n\ncompression::String enables compression of the node outputs.\n\nAvailable options are \"none\", for no compression, \"bz2\" or \"bzip2\" for BZIP compression and \"gz\" or \"gzip\" for GZIP compression\n\ncachedir::String the cache directory.\n\nNote: This function should be used with care as it modifies the input       dispatch graph. One way to handle this is to make a function that       generates the dispatch graph and calling cache! each time on       the distict, functionally identical graphs.\n\n\n\n\n\n"
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
    "location": "api/#DispatcherCache.get_dependencies-Union{Tuple{T}, Tuple{DispatchGraph,Type{T}}} where T<:Dispatcher.DispatchNode",
    "page": "API Reference",
    "title": "DispatcherCache.get_dependencies",
    "category": "method",
    "text": "get_dependencies(graph, ::Type{T})\n\nReturns a dictionary where the keys are, depending on T, the node labels or nodes of graph::DsipatchGraph and vthe alues are iterators over either the node labels or nodes corresponding to the depencies of the key node.\n\n\n\n\n\n"
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
    "location": "api/#DispatcherCache.get_keys-Union{Tuple{T}, Tuple{DispatchGraph,Type{T}}} where T<:Dispatcher.DispatchNode",
    "page": "API Reference",
    "title": "DispatcherCache.get_keys",
    "category": "method",
    "text": "get_keys(graph, ::Type{T})\n\nReturns an iterator of the nodes of the dispatch graph graph. The returned iterator generates elements of type T: if T<:AbstractString the iterator is over the labels of the graph, if T<:DispatchNode the iterator is over the nodes of the graph.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_node-Union{Tuple{T}, Tuple{DispatchGraph,T}} where T<:Dispatcher.DispatchNode",
    "page": "API Reference",
    "title": "DispatcherCache.get_node",
    "category": "method",
    "text": "get_node(graph, label)\n\nReturns the node corresponding to label.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.get_source_hash-Tuple{Dispatcher.Op}",
    "page": "API Reference",
    "title": "DispatcherCache.get_source_hash",
    "category": "method",
    "text": "get_source_hash(node)\n\nHashes the lowered representation of the source code of the function associated with node. Useful for Op nodes, the other node types do not have any associated source code.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.load_hashchain",
    "page": "API Reference",
    "title": "DispatcherCache.load_hashchain",
    "category": "function",
    "text": "load_hashchain(cachedir [; compression=DEFAULT_COMPRESSION])\n\nLoads the hashchain file found in the directory cachedir. Before loading, the compression value is checked against the one stored in the hashchain file (both have to match). If the file does not exist, it is created.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.root_nodes-Tuple{Dispatcher.DispatchGraph}",
    "page": "API Reference",
    "title": "DispatcherCache.root_nodes",
    "category": "method",
    "text": "root_nodes(graph::DispatchGraph) ->\n\nReturn an iterable of all nodes in the graph with no input edges.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.store_hashchain",
    "page": "API Reference",
    "title": "DispatcherCache.store_hashchain",
    "category": "function",
    "text": "store_hashchain(hashchain, cachedir=DEFAULT_CACHE_DIR [; compression=DEFAULT_COMPRESSION, version=1])\n\nStores the hashchain object in a file named DEFAULT_HASHCHAIN_FILENAME, in the directory cachedir. The values of compression and version are stored as well in the file.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.wrap_to_load!-Tuple{Dict{Dispatcher.DispatchNode,Dispatcher.DispatchNode},Dispatcher.DispatchNode,String}",
    "page": "API Reference",
    "title": "DispatcherCache.wrap_to_load!",
    "category": "method",
    "text": "wrap_to_load!(updates, node, nodehash; cachedir=DEFAULT_CACHE_DIR, compression=DEFAULT_COMPRESSION)\n\nGenerates a new dispatch node that corresponds to node::DispatchNode and which loads a file from the cachedir cache directory whose name and extension depend on nodehash and compression and contents are the output of node. The generated node is added to updates which maps node to the generated node.\n\n\n\n\n\n"
},

{
    "location": "api/#DispatcherCache.wrap_to_store!-Tuple{Dict{Dispatcher.DispatchNode,Dispatcher.DispatchNode},Dispatcher.DispatchNode,String}",
    "page": "API Reference",
    "title": "DispatcherCache.wrap_to_store!",
    "category": "method",
    "text": "wrap_to_store!(graph, node, nodehash; compression=DEFAULT_COMPRESSION)\n\nGenerates a new dispatch node that corresponds to node::DispatchNode and which stores the output of the execution of node in a file whose name and extension depend on nodehash and compression. The generated node is added to updates which maps node to the generated node.\n\n\n\n\n\n"
},

{
    "location": "api/#",
    "page": "API Reference",
    "title": "API Reference",
    "category": "page",
    "text": "Modules = [DispatcherCache]"
},

]}
