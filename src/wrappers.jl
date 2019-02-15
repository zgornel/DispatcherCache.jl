###"""
###    wrap_to_load!(graph, node, nodehash; cachedir=DEFAULT_CACHE_DIR, compression=DEFAULT_COMPRESSION)
###
###Wraps the callable field `func` of `node::DispatchNode` to load a file from
###the `cachedir` cache directory whose name and extension depend on `nodehash`
###and `compression`. It updates only occurences of the `node` in the `graph` and
###not in the individual dependencies of the nodes.
###"""
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
        @info "[$nodehash][$(node.label)] $operation (compression=$compression)"
        result = open(decompressor, filepath, "r") do fid
                    deserialize(fid)
                 end
        return result
    end

    newnode = Op(loading_wrapper)
    newnode.label = node.label
    push!(updates, node => newnode)
    return nothing
end


###"""
###    wrap_to_store!(graph, node, nodehash; compression=DEFAULT_COMPRESSION)
###
###Wraps the callable field `func` of `node::DispatchNode` to load a file whose name
###and extension depend on `nodehash` and `compression`. It updates all
###occurences of the `node` in the `graph`
###"""
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
        # TODO(Corneliu) handle other types of DispatchNode
        result = node.func(args...; kwargs...)
        # Store result
        @info "[$nodehash][$(node.label)] $operation (compression=$compression)"
        if !skipcache
            if !isfile(filepath)
                open(compressor, filepath, "w") do fid
                    serialize(fid, result)
                end
            else
                @info "`-->[$nodehash][$(node.label)] * SKIPPING $operation"
            end
        end
        return result
    end

    # Update all nodes in the graph
    newnode = Op(exec_store_wrapper)
    newnode.label = node.label
    newnode.args = map(node.args) do arg
        if arg isa DispatchNode
            get(updates, arg, arg)
        else
            arg
        end
    end
    newnode.kwargs = pairs(NamedTuple())  #TODO Fix this
    push!(updates, node=>newnode)
    return nothing
end
