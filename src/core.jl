"""
    cache!(graph, endpoints, uncacheable, compression=DEFAULT_COMPRESSION, cachedir=DEFAULT_CACHE_DIR)

Optimizes a delayed execution graph `graph::DispatchGraph`
by wrapping individual nodes in load-from-disk on execute-and-store
wrappers depending on the state of the disk cache and of the graph.
The function modifies inplace the input graph and should be called on
the same unmodified `graph` after each execution and *not* on the
modified graph.

Once the original graph is modified, calling `run!` on it will,
if the cache is already present, load the top most consistent key
or alternatively re-run and store the outputs of nodes which have new state.

# Arguments
  * `graph::DispatchGraph` input graph
  * `endpoints::Vector{Union{DispatchNode, AbstractString}}` top nodes for which
caching will occur; nodes that depend on these will not be cached. The nodes
can be specified either by label of by the node object itself
  * uncacheable::Vector{Union{DispatchNode, AbstractString}}` nodes that will
never be cached and will always be executed (these nodes are still hashed and
their hashes influence upstream node hashes as well)

# Keyword arguments
  * `compression::String` enables compression of the node outputs.
Available options are `"none"`, for no compression, `"bz2"` or `"bzip2"`
for BZIP compression and `"gz"` or `"gzip"` for GZIP compression
  * `cachedir::String` The cache directory.

# Examples
```
julia> # TODO ...
```
"""
function cache!(graph::DispatchGraph,
                endpoints::Vector{T}=T[],
                uncacheable::Vector{T}=T[];
                compression::String=DEFAULT_COMPRESSION,
                cachedir::String=DEFAULT_CACHE_DIR
               ) where T<:Union{<:DispatchNode, <:AbstractString}
    # Checks
    if isempty(endpoints)
        @warn "No enpoints for graph, will not process dispatch graph."
        return nothing
    end

    # Initializations
    subgraph = Dispatcher.subgraph(
                    graph, map(n->get_node(graph, n), endpoints))

    work = Deque{T}()                           # keys to be traversed
    for key in get_keys(graph, T)
        push!(work, key)
    end
    solved = Set()                              # keys of computable tasks
    dependencies = get_dependencies(graph, T)   # dependencies of all tasks
    keyhashmaps = Dict{T, String}()             # key=>hash mapping
    hashes_to_store = Set{String}()             # hashes of nodes with storable output
    updates = Dict{DispatchNode, DispatchNode}()

    # Load hashchain
    hashchain = load_hashchain(cachedir, compression=compression)
    # Traverse dispatch graph
    while !isempty(work)
        key = popfirst!(work)
        deps = dependencies[key]
        if isempty(deps) || issubset(deps, solved)
            # Node is solvable
            push!(solved, key)
            node = get_node(graph, key)          # The node is always a DispatchNode
            _hash_node, _hash_comp = get_hash(node, keyhashmaps)
            keyhashmaps[key] = _hash_node
            skipcache = key in uncacheable || !(node in subgraph.nodes)
            # Wrap nodes
            if _hash_node in keys(hashchain) && !skipcache &&
                    !(_hash_node in hashes_to_store)
                # Hash match and output cacheable
                wrap_to_load!(updates, node, _hash_node,
                              cachedir=cachedir,
                              compression=compression)
            elseif _hash_node in keys(hashchain) && skipcache
                # Hash match and output *non-cachable*
                wrap_to_store!(updates, node, _hash_node,
                               cachedir=cachedir,
                               compression=compression,
                               skipcache=skipcache)
            else
                # Hash miss
                hashchain[_hash_node] = _hash_comp
                push!(hashes_to_store, _hash_node)
                wrap_to_store!(updates, node, _hash_node,
                               cachedir=cachedir,
                               compression=compression,
                               skipcache=skipcache)
            end
        else
            # Non-solvable node
            push!(work, key)
        end
    end
    # Update graph
    for i in 1:length(graph.nodes)
        graph.nodes[i] = updates[graph.nodes[i]]
    end
    # Write hashchain
    store_hashchain(hashchain, cachedir, compression=compression)
    return updates
end


function runcached!(exec::Executor,
                    graph::DispatchGraph,
                    endpoints::Vector{T}=T[],
                    uncacheable::Vector{T}=T[];
                    compression::String=DEFAULT_COMPRESSION,
                    cachedir::String=DEFAULT_CACHE_DIR
                   ) where T<:Union{<:DispatchNode, <:AbstractString}
    _graph = Base.deepcopy(graph)
    nodemap = Dict(graph.nodes[i] => _graph.nodes[i] for i in 1:length(graph.nodes))
    mapped_endpoints = [nodemap[get_node(graph, node)] for node in endpoints]
    mapped_uncacheable = [nodemap[get_node(graph, node)] for node in uncacheable]
    # Modify input graph
    updates = cache!(_graph,
                     mapped_endpoints,
                     mapped_uncacheable,
                     compression=compression,
                     cachedir=cachedir)
    # Run temporary graph
    return run!(exec, [updates[e] for e in mapped_endpoints])
end
