get_keys(dsk::DispatchGraph, ::Type{T}) where T<:DispatchNode =
    keys(dsk.nodes.node_dict)

get_keys(dsk::DispatchGraph, ::Type{T}) where T<:AbstractString =
    imap(x->x.label, get_keys(dsk, DispatchNode))


get_dependencies(dsk::DispatchGraph, ::Type{T}) where T<:DispatchNode =
    Dict(k => collect(dependencies(k)) for k in get_keys(dsk, T))

get_dependencies(dsk::DispatchGraph, ::Type{T}) where T<:AbstractString =
    Dict(k.label => collect(imap(x->x.label, dependencies(k)))
         for k in get_keys(dsk, DispatchNode))


get_node(dsk::DispatchGraph, node::T) where T<:DispatchNode = node

get_node(dsk::DispatchGraph, label::T) where T<:AbstractString = begin
    nodes = [node for node in get_keys(dsk, DispatchNode) if node.label==label]
    length(nodes) != 1 && throw(ExceptionError("Labels in dispatch graph are not unique!"))
    return nodes[1]
end


"""
    get_hash(node, keyhashmaps)

Calculates and returns the hash corresponding to a `Dispatcher` task graph
node i.e. `DispatchNode` using the hashes of its dependencies, input arguments
and source code of the function associated to the `node`. Any available hashes
are taken from `keyhashmap`.
"""
function get_hash(node::DispatchNode, keyhashmaps::Dict{T,String}) where T
    hash_code = get_source_hash(node)
    hash_arguments = get_arguments_hash(node)
    hash_dependencies = get_dependencies_hash(node, keyhashmaps)

    node_hash = __hash(join(hash_code, hash_arguments, hash_dependencies))
    subgraph_hash = Dict("code" => hash_code,
                         "args" => hash_arguments,
                         "deps" => hash_dependencies)
    return node_hash, subgraph_hash
end

get_source_hash(node::DispatchNode) = begin
    f = node.func
    code = join(code_lowered(f)[1].code, "\n")
    return __hash(code)
end

get_source_hash(node::DataNode) = __hash(nothing)


get_arguments_hash(node::DispatchNode) = begin
    h = hash(nothing)
    arguments = (arg for arg in node.args if !(arg isa DispatchNode))
    if !isempty(arguments)
        h += mapreduce(+, arguments) do x
                hash(x) + hash(typeof(x))
            end
    end
    kwarguments = ((k,v) for (k,v) in node.kwargs if !(v isa DispatchNode))
    if !isempty(kwarguments)
        h += mapreduce(+, kwarguments) do x
                k, v = x
                hash(k) + hash(v) + hash(typeof(v))
            end
    end
    return __hash(h)
end

get_arguments_hash(node::DataNode) = __hash(nothing)


get_dependencies_hash(node::DispatchNode, keyhashmaps) = begin
    h = __hash(nothing)
    node_arguments = (arg for arg in node.args if arg isa DispatchNode)
    regular_arguments = (arg for arg in node.args if !(arg isa DispatchNode))
    if !isempty(regular_arguments)
        h *= get_arguments_hash(node)
    end
    if isempty(node_arguments)
        return __hash(h)
    else
        for node in node_arguments
            h *= get(keyhashmaps, node, get_dependencies_hash(node, keyhashmaps))
        end
        return __hash(h)
    end
end

get_dependencies_hash(node::DataNode, keyhashmaps) = __hash(nothing)


"""
    __hash(something)

Return a hexadecimal string corresponding to the hash of sum
of the hashes of the value and type of `something`.
"""
function __hash(something)
    h = hash(hash(typeof(something)) + hash(something))
    return string(h, base=16)
end


"""
    load_hashchain(cachedir [; compression=DEFAULT_COMPRESSION])

Loads the hashchain file found in the directory `cachedir`. Before
loading, the `compression` value is checked against the one stored
in the hashchain file (both have to match). If the file does not exist,
it is created.
"""
function load_hashchain(cachedir::String=DEFAULT_CACHE_DIR;
                        compression::String=DEFAULT_COMPRESSION)
    cachedir = abspath(cachedir)
    file = joinpath(cachedir, DEFAULT_HASHCHAIN_FILENAME)
    cachedir_outputs = joinpath(cachedir, DEFAULT_HASHCACHE_DIR)
    if !ispath(cachedir_outputs)
        @info "Creating the cache directory..."
        mkpath(cachedir_outputs)
    end

    local hashchain
    if !isfile(file)
        @info "Creating a new hashchain file $file..."
        hashchain = Dict{String, String}()
        store_hashchain(hashchain, cachedir, compression=compression)
    else
        local data
        open(file, "r") do fid  # read the whole JSON hashchain file
            data = JSON.parse(read(fid, String))
        end
        if compression != data["compression"]
            throw(ExceptionError("Compression mismatch: $compression vs. "*
                                 "$(hashchain["compression"])"))e
        end
        hashchain = data["hashchain"]
        ### # Clean up hashchain based on what exists already on disk
        ### # i.e. remove keys not found on disk
        ### on_disk_hashes = map(filename->split(filename, ".")[0],
        ###                      filter!(isfile, readdir(cachedir_outputs)))
        ### keys_to_delete = setdiff(keys(hashchain), on_disk_hashes)
        ### for key in keys_to_delete
        ###     delete!(hashchain, key)
        ### end
        ### store_hashchain(hashchain, cachedir, compression=compression)
    end
    return hashchain
end


"""
    store_hashchain(hashchain, cachedir=DEFAULT_CACHE_DIR [; compression=DEFAULT_COMPRESSION, version=1])

Stores the `hashchain` object in a file named `DEFAULT_HASHCHAIN_FILENAME`,
in the directory `cachedir`. The values of `compression` and `version` are
stored as well in the file.
"""
function store_hashchain(hashchain::Dict{String, Any},
                         cachedir::String=DEFAULT_CACHE_DIR;
                         compression::String=DEFAULT_COMPRESSION,
                         version::Int=1)
    cachedir = abspath(cachedir)
    if !ispath(cachedir)
        @info "Creating the cache directory..."
        mkpath(cachedir)
    end
    file = joinpath(cachedir, DEFAULT_HASHCHAIN_FILENAME)
    hashchain = Dict("version" => version,
                     "compression" => compression,
                     "hashchain" => hashchain)
    open(file, "w+") do fid
        write(fid, JSON.json(hashchain, 4))
    end
end


"""
    get_compressor(compression, action)

Return a `TranscodingStreams` compatible compressor or decompressor
based on the values of `compression` and `action`.
"""
function get_compressor(compression::AbstractString, action::AbstractString)
    # Checks
    if !(compression in ["bz2", "bzip2", "gz", "gzip", "none"])
        @warn "Unknown compression option, defaulting to $DEFAULT_COMPRESSION."
        compression = DEFAULT_COMPRESSION
    end
    if !(action in ["compress", "decompress"])
        throw(ExceptionError("The action can only be \"compress\" or \"decompress\"."))
    end
    # Get compressor/decompressor
    if compression == "bz2" || compression == "bzip2"
        compressor = ifelse(action == "compress", Bzip2Compressor, Bzip2Decompressor)
    elseif compression == "gz" || compression == "gzip"
        compressor = ifelse(action == "compress", GzipCompressor, GzipDecompressor)
    elseif compression == "none"
        compressor = Noop  # no compression
    end
    return compressor
end


"""
    input_nodes(graph::DispatchGraph) ->

Return an iterable of all nodes in the graph with no input edges.
"""
function input_nodes(graph::DispatchGraph)
    imap(n->graph.nodes[n], filter(1:nv(graph.graph)) do node_index
        indegree(graph.graph, node_index) == 0
    end)
end
