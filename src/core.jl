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
    # Initializations
    if isempty(endpoints)
        @warn "No enpoints for graph, will not process dispatch graph."
        return nothing
    end
    subgraph = Dispatcher.subgraph(
                    graph, map(n->get_node(graph, n), endpoints))

    hashchain = load_hashchain(cachedir, compression=compression)
    allkeys = get_keys(graph, T)  # all keys in the dispatch graph
    work = Deque{T}()             # keys to be traversed
    for key in allkeys
        push!(work, key)
    end
    solved = Set()                             # keys of computable tasks
    dependencies = get_dependencies(graph, T)
    keyhashmaps = Dict{T, String}()            # key=>hash mapping
    hashes_to_store = Set{String}()            # list of hashes that correspond
                                               #   to keys whose output will be stored
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
                wrap_to_load!(graph, node, _hash_node,
                              cachedir=cachedir,
                              compression=compression)
            elseif _hash_node in keys(hashchain) && skipcache
                # Hash match and output *non-cachable*
                wrap_to_store!(graph, node, _hash_node,
                               cachedir=cachedir,
                               compression=compression,
                               skipcache=skipcache)
            else
                # Hash miss
                # TODO(Corneliu) Analyze hash miss
                hashchain[_hash_node] = _hash_comp
                push!(hashes_to_store, _hash_node)
                wrap_to_store!(graph, node, _hash_node,
                               cachedir=cachedir,
                               compression=compression,
                               skipcache=skipcache)
            end
        else
            # Non-solvable node
            push!(work, key)
        end
    end
    # Write hashchain
    store_hashchain(hashchain, cachedir, compression=compression)
    return nothing
end
