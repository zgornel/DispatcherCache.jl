"""
    add_hash_cache!(graph, endpoints=[], uncacheable=[]
                    [; compression=DEFAULT_COMPRESSION, cachedir=DEFAULT_CACHE_DIR])

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
  * `exec::Executor` the `Dispatcher.jl` executor
  * `graph::DispatchGraph` input dispatch graph
  * `endpoints::AbstractVector` leaf nodes for which caching will occur;
nodes that depend on these will not be cached. The nodes can be specified
either by label of by the node object itself
  * uncacheable::AbstractVector` nodes that will never be cached and
will always be executed (these nodes are still hashed and their hashes
influence upstream node hashes as well)

# Keyword arguments
  * `compression::String` enables compression of the node outputs.
Available options are `"none"`, for no compression, `"bz2"` or `"bzip2"`
for BZIP compression and `"gz"` or `"gzip"` for GZIP compression
  * `cachedir::String` the cache directory.

Note: This function should be used with care as it modifies the input
      dispatch graph. One way to handle this is to make a function that
      generates the dispatch graph and calling `add_hash_cache!` each time on
      the distict, functionally identical graphs.
"""
function add_hash_cache!(graph::DispatchGraph,
                         endpoints::AbstractVector=[],
                         uncacheable::AbstractVector=[];
                         compression::String=DEFAULT_COMPRESSION,
                         cachedir::String=DEFAULT_CACHE_DIR)
    # Checks
    if isempty(endpoints)
        @warn "No enpoints for graph, will not process dispatch graph."
        return nothing
    end

    # Initializations
    _endpoints = map(n->get_node(graph, n), endpoints)
    _uncacheable = imap(n->get_node(graph, n), uncacheable)
    subgraph = Dispatcher.subgraph(graph, _endpoints)
    work = collect(nodes(graph))                # nodes to be traversed
    solved = Set{DispatchNode}()                # computable tasks
    node2hash = Dict{DispatchNode, String}()    # node => hash mapping
    storable = Set{String}()                    # hashes of nodes with storable output
    updates = Dict{DispatchNode, DispatchNode}()

    # Load hashchain
    hashchain = load_hashchain(cachedir, compression=compression)
    # Traverse dispatch graph
    while !isempty(work)
        node = popfirst!(work)
        deps = dependencies(node)
        if isempty(deps) || issubset(deps, solved)
            # Node is solvable
            push!(solved, node)
            _hash_node, _hash_comp = node_hash(node, node2hash)
            node2hash[node] = _hash_node
            skipcache = node in _uncacheable || !(node in subgraph.nodes)
            # Wrap nodes
            if _hash_node in keys(hashchain) && !skipcache &&
                    !(_hash_node in storable)
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
                push!(storable, _hash_node)
                wrap_to_store!(updates, node, _hash_node,
                               cachedir=cachedir,
                               compression=compression,
                               skipcache=skipcache)
            end
        else
            # Non-solvable node
            push!(work, node)
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


"""
    run!(exec, graph, endpoints, uncacheable=[]
         [;compression=DEFAULT_COMPRESSION, cachedir=DEFAULT_CACHE_DIR])

Runs the `graph::DispatchGraph` and loads or executes and stores the
outputs of the nodes in the subgraph whose leaf nodes are given by
`endpoints`. Nodes in `uncachable` are not locally cached.

# Arguments
  * `exec::Executor` the `Dispatcher.jl` executor
  * `graph::DispatchGraph` input dispatch graph
  * `endpoints::AbstractVector` leaf nodes for which caching will occur;
nodes that depend on these will not be cached. The nodes can be specified
either by label of by the node object itself
  * `uncacheable::AbstractVector` nodes that will never be cached and will
always be executed (these nodes are still hashed and their hashes influence
upstream node hashes as well)

# Keyword arguments
  * `compression::String` enables compression of the node outputs.
Available options are `"none"`, for no compression, `"bz2"` or `"bzip2"`
for BZIP compression and `"gz"` or `"gzip"` for GZIP compression
  * `cachedir::String` The cache directory.

# Examples
```julia
julia> using Dispatcher
       using DispatcherCache

       # Some functions
       foo(x) = begin sleep(1); x end
       bar(x) = begin sleep(1); x+1 end
       baz(x,y) = begin sleep(1); x-y end

       # Make a dispatch graph out of some operations
       op1 = @op foo(1)
       op2 = @op bar(2)
       op3 = @op baz(op1, op2)
       D = DispatchGraph(op3)
# DispatchGraph({3, 2} directed simple Int64 graph,
# NodeSet(DispatchNode[
# Op(DeferredFuture at (1,1,241),baz,"baz"),
# Op(DeferredFuture at (1,1,239),foo,"foo"),
# Op(DeferredFuture at (1,1,240),bar,"bar")]))

julia> # First run, writes results to disk (lasts 2 seconds)
       result_node = [op3]  # the node for which we want results
       cachedir = "./__cache__"  # directory does not exist
       @time r = run!(AsyncExecutor(), D,
                      result_node, cachedir=cachedir)
       println("result (first run) = \$(fetch(r[1].result.value))")
# [info | Dispatcher]: Executing 3 graph nodes.
# [info | Dispatcher]: Node 1 (Op<baz, Op<foo>, Op<bar>>): running.
# [info | Dispatcher]: Node 2 (Op<foo, Int64>): running.
# [info | Dispatcher]: Node 3 (Op<bar, Int64>): running.
# [info | Dispatcher]: Node 2 (Op<foo, Int64>): complete.
# [info | Dispatcher]: Node 3 (Op<bar, Int64>): complete.
# [info | Dispatcher]: Node 1 (Op<baz, Op<foo>, Op<bar>>): complete.
# [info | Dispatcher]: All 3 nodes executed.
#   2.029992 seconds (11.53 k allocations: 1.534 MiB)
# result (first run) = -2

julia> # Secod run, loads directly the result from ./__cache__
       @time r = run!(AsyncExecutor(), D,
                      [op3], cachedir=cachedir)
       println("result (second run) = \$(fetch(r[1].result.value))")
# [info | Dispatcher]: Executing 1 graph nodes.
# [info | Dispatcher]: Node 1 (Op<baz>): running.
# [info | Dispatcher]: Node 1 (Op<baz>): complete.
# [info | Dispatcher]: All 1 nodes executed.
#   0.005257 seconds (2.57 k allocations: 478.359 KiB)
# result (second run) = -2

julia> readdir(cachedir)
# 2-element Array{String,1}:
#  "cache"
#  "hashchain.json"
```
"""
function run!(exec::Executor,
              graph::DispatchGraph,
              endpoints::AbstractVector,
              uncacheable::AbstractVector=[];
              compression::String=DEFAULT_COMPRESSION,
              cachedir::String=DEFAULT_CACHE_DIR)
    # Make a copy of the input graph that will be modified
    # and mappings from the original nodes to the copies
    tmp_graph = Base.deepcopy(graph)
    node2tmpnode = Dict(graph.nodes[i] => tmp_graph.nodes[i]
                        for i in 1:length(graph.nodes))
    # Construct the endpoints and uncachable node lists
    # for the copied dispatch graph
    tmp_endpoints = [node2tmpnode[get_node(graph, node)]
                     for node in endpoints]
    tmp_uncacheable = [node2tmpnode[get_node(graph, node)]
                       for node in uncacheable]
    # Modify input graph
    updates = add_hash_cache!(tmp_graph,
                              tmp_endpoints,
                              tmp_uncacheable,
                              compression=compression,
                              cachedir=cachedir)
    # Run temporary graph
    return run!(exec, [updates[e] for e in tmp_endpoints])
end
