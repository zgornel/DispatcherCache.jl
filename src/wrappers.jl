"""
    wrap_to_load!(updates, node, nodehash;
                  cachedir=DEFAULT_CACHE_DIR,
                  compression=DEFAULT_COMPRESSION)

Generates a new dispatch node that corresponds to `node::DispatchNode`
and which loads a file from the `cachedir` cache directory whose name and extension
depend on `nodehash` and `compression` and contents are the output of `node`.
The generated node is added to `updates` which maps `node` to the generated node.
"""
function wrap_to_load!(updates::Dict{DispatchNode, DispatchNode},
                       node::DispatchNode,
                       nodehash::String;
                       cachedir::String=DEFAULT_CACHE_DIR,
                       compression::String=DEFAULT_COMPRESSION)
    # Defing loading wrapper function
    """
    Simple load wrapper.
    """
    function loading_wrapper()
        _cachedir = abspath(joinpath(expanduser(cachedir), DEFAULT_HASHCACHE_DIR))
        if compression != "none"
            extension = ".$compression"
            operation = "LOAD-UNCOMPRESS"
        else
            extension = ".bin"
            operation = "LOAD"
        end
        filepath = joinpath(_cachedir, nodehash * extension)
        decompressor = get_compressor(compression, "decompress")
        label = _labelize(node, nodehash)
        @debug "[$nodehash][$(label)] $operation (compression=$compression)"
        if isfile(filepath)
            result = open(decompressor, filepath, "r") do fid
                        deserialize(fid)
                    end
        else
            throw(ErrorException("Cache file $filepath is missing."))
        end
        return result
    end

    # Add wrapped node to updates (no arguments to update :)
    newnode = Op(loading_wrapper)
    newnode.label = _labelize(node, nodehash)
    push!(updates, node => newnode)
    return nothing
end


"""
    wrap_to_store!(graph, node, nodehash;
                   cachedir=DEFAULT_CACHE_DIR,
                   compression=DEFAULT_COMPRESSION,
                   skipcache=false)

Generates a new `Op` node that corresponds to `node::DispatchNode`
and which stores the output of the execution of `node` in a file whose
name and extension depend on `nodehash` and `compression`. The generated
node is added to `updates` which maps `node` to the generated node. The
node output is stored in `cachedir`. The caching is skipped if `skipcache`
is `true`.
"""
function wrap_to_store!(updates::Dict{DispatchNode, DispatchNode},
                        node::DispatchNode,
                        nodehash::String;
                        cachedir::String=DEFAULT_CACHE_DIR,
                        compression::String=DEFAULT_COMPRESSION,
                        skipcache::Bool=false)
    # Defing exec-store wrapper function
    """
    Simple exec-store wrapper.
    """
    function exec_store_wrapper(args...; kwargs...)
        _cachedir = abspath(joinpath(expanduser(cachedir), DEFAULT_HASHCACHE_DIR))
        if compression != "none" && !skipcache
            operation = "EXEC-STORE-COMPRESS"
        elseif compression == "none" && !skipcache
            operation = "EXEC-STORE"
        else
            operation = "EXEC *ONLY*"
        end
        extension = ifelse(compression != "none", ".$compression", ".bin")
        filepath = joinpath(_cachedir, nodehash * extension)
        compressor = get_compressor(compression, "compress")

        # Get calculation result
        result = _run_node(node, args...; kwargs...)

        # Store result
        label = _labelize(node, nodehash)
        @debug "[$nodehash][$(label)] $operation (compression=$compression)"
        if !skipcache
            if !isfile(filepath)
                open(compressor, filepath, "w") do fid
                    serialize(fid, result)
                end
            else
                @debug "`-->[$nodehash][$(node.label)] * SKIPPING $operation"
            end
        end
        return result
    end

    # Update arguments and keyword arguments of node using the updates;
    # the latter should contain at this point only solved nodes (so the
    # dependencies of the current node should be good.
    newnode = Op(exec_store_wrapper)
    newnode.label = _labelize(node, nodehash)
    newnode.args = _arguments(node, updates)
    newnode.kwargs = _kwarguments(node, updates)
    # Add wrapped node to updates
    push!(updates, node=>newnode)
    return nothing
end


# Small wrapper that executes a node
_run_node(node::Op, args...; kwargs...) = node.func(args...; kwargs...)

_run_node(node::IndexNode, args...; kwargs...) = getindex(args..., node.index)

_run_node(node::CollectNode, args...; kwargs...) = vcat(args...)

_run_node(node::DataNode, args...; kwargs...) = identity(args...)


# Small wrapper that gets the label for a wrapped node
_labelize(node::Op, args...) = get_label(node)

_labelize(node::CollectNode, args...) = get_label(node)

_labelize(node::IndexNode, nodehash::String) = "IndexNode_$nodehash"

_labelize(node::DataNode, nodehash::String) = "DataNode_$nodehash"


# Small wrapper that generates new arguments for a wrapped node
_arguments(node::Op, updates) = map(node.args) do arg
    ifelse(arg isa DispatchNode, get(updates, arg, arg), arg)
end

_arguments(node::IndexNode, updates) =
    tuple(get(updates, node.node, node.node))

_arguments(node::CollectNode, updates) =
    Tuple(get(updates, n, n) for n in node.nodes)

_arguments(node::DataNode, updates) =
    tuple(ifelse(node.data isa DispatchNode,
                 get(updates, node.data, node.data),
                 node.data))


# Small wrapper that generates new keyword arguments for a wrapped node
_kwarguments(node::Op, updates) = pairs(
    NamedTuple{(node.kwargs.itr...,)}(
        ((map(node.kwargs.data) do kwarg
                 ifelse(kwarg isa DispatchNode, get(updates, kwarg, kwarg), kwarg)
             end)...,)))

_kwarguments(node::DispatchNode, updates) = pairs(NamedTuple())
