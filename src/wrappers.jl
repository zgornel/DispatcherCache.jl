"""
    wrap_to_load!(graph, node, nodehash; cachedir=DEFAULT_CACHE_DIR, compression=DEFAULT_COMPRESSION)

Wraps the callable field `func` of `node::DispatchNode` to load a file from
the `cachedir` cache directory whose name and extension depend on `nodehash`
and `compression`. It updates only occurences of the `node` in the `graph` and
not in the individual dependencies of the nodes.
"""
function wrap_to_load!(graph::DispatchGraph,
                       node::DispatchNode,
                       nodehash::String;
                       cachedir::String=DEFAULT_CACHE_DIR,
                       compression::String=DEFAULT_COMPRESSION)
    index = graph.nodes[node]
    # Defing loading wrapper function
    """
    Simple load wrapper.
    """
    function loading_wrapper()
        _cachedir = abspath(joinpath(cachedir, DEFAULT_HASHCACHE_DIR))
        if compression != "none"
            extension = ".$compression"
            operation = "LOAD-UNCOMPRESS"
        else
            extension = ".bin"
            operation = "LOAD"
        end
        filepath = joinpath(_cachedir, nodehash * extension)
        decompressor = get_compressor(compression, "decompress")
        @info "[$index][$nodehash][$(node.label)] $operation (compression=$compression)"
        result = open(decompressor, filepath, "r") do fid
                    deserialize(fid)
                 end
        return result
    end

    # Update all nodes in the graph
    newnode = Op(loading_wrapper)
    newnode.label = node.label
    graph.nodes[index] = newnode
    return nothing
end


"""
    wrap_to_store!(graph, node, nodehash; compression=DEFAULT_COMPRESSION)

Wraps the callable field `func` of `node::DispatchNode` to load a file whose name
and extension depend on `nodehash` and `compression`. It updates all
occurences of the `node` in the `graph`
"""
function wrap_to_store!(graph::DispatchGraph,
                        node::DispatchNode,
                        nodehash::String;
                        cachedir::String=DEFAULT_CACHE_DIR,
                        compression::String=DEFAULT_COMPRESSION,
                        skipcache::Bool=false)
    index = graph.nodes[node]
    # Defing exec-store wrapper function
    """
    Simple exec-store wrapper.
    """
    function exec_store_wrapper(args...; kwargs...)
        _cachedir = abspath(joinpath(cachedir, DEFAULT_HASHCACHE_DIR))
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
        result = node.func(args...; kwargs...)
        # Store result
        @info "[$index][$nodehash][$(node.label)] $operation (compression=$compression)"
        if !skipcache
            if !isfile(filepath)
                open(compressor, filepath, "w") do fid
                    serialize(fid, result)
                end
            else
                @info "`-->[$index][$nodehash][$(node.label)] * SKIPPING $operation"
            end
        end
        return result
    end

    # Update all nodes in the graph
    newnode = Op(exec_store_wrapper, node.args...; node.kwargs...)
    newnode.label = node.label
    graph.nodes[index] = newnode
    return nothing
end
