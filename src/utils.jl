"""
    get_keys(graph, ::Type{T})

Returns an iterator of the nodes of the dispatch graph `graph`.
The returned iterator generates elements of type `T`: if
`T<:AbstractString` the iterator is over the labels of the graph,
if `T<:DispatchNode` the iterator is over the nodes of the graph.
"""
get_keys(graph::DispatchGraph, ::Type{T}) where T<:DispatchNode =
    keys(graph.nodes.node_dict)

#TODO(Corneliu) Improve this bit and connected logic
get_keys(graph::DispatchGraph, ::Type{T}) where T<:AbstractString =
    imap(get_keys(graph, DispatchNode)) do node
        has_label(node) ? get_label(node) : ""
    end


"""
    get_dependencies(graph, ::Type{T})

Returns a dictionary where the keys are, depending on `T`, the node labels
or nodes of `graph::DsipatchGraph` and vthe alues are iterators over either
the node labels or nodes corresponding to the depencies of the key node.
"""
get_dependencies(graph::DispatchGraph, ::Type{T}) where T<:DispatchNode =
    Dict(k => (dependencies(k)) for k in get_keys(graph, T))

get_dependencies(graph::DispatchGraph, ::Type{T}) where T<:AbstractString =
    Dict(k.label => imap(x->x.label, dependencies(k))
         for k in get_keys(graph, DispatchNode))


"""
    get_node(graph, label)

Returns the node corresponding to `label`.
"""
get_node(graph::DispatchGraph, node::T) where T<:DispatchNode = node

get_node(graph::DispatchGraph, label::T) where T<:AbstractString = begin
    found = Set{DispatchNode}()
    for node in get_keys(graph, DispatchNode)
        get_label(node) == label && push!(found, node)
    end
    length(found) > 1 && throw(ErrorException("Labels in dispatch graph are not unique."))
    length(found) < 1 && throw(ErrorException("No nodes with label $label found."))
    return pop!(found)
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
        @debug "Creating the cache directory..."
        mkpath(cachedir_outputs)
    end

    local hashchain
    if !isfile(file)
        @debug "Creating a new hashchain file $file..."
        hashchain = Dict{String, Any}()
        store_hashchain(hashchain, cachedir, compression=compression)
    else
        local data
        open(file, "r") do fid  # read the whole JSON hashchain file
            data = JSON.parse(read(fid, String))
        end
        if compression != data["compression"]
            throw(ErrorException("Compression mismatch: $compression vs. "*
                                 "$(data["compression"])"))
        end
        hashchain = data["hashchain"]
        # Clean up hashchain based on what exists already on disk
        # i.e. remove keys not found on disk
        on_disk_hashes = map(filename->split(filename, ".")[1],
                             filter!(!isfile, readdir(cachedir_outputs)))
        keys_to_delete = setdiff(keys(hashchain), on_disk_hashes)
        for key in keys_to_delete
            delete!(hashchain, key)
        end
        store_hashchain(hashchain, cachedir, compression=compression)
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
        @debug "Creating the cache directory..."
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
        throw(ErrorException("Unknown compression option,"*
                             " aborting."))
    end
    if !(action in ["compress", "decompress"])
        throw(ErrorException("The action can only be \"compress\" or \"decompress\"."))
    end
    # Get compressor/decompressor
    if compression == "bz2" || compression == "bzip2"
        compressor = ifelse(action == "compress",
                            Bzip2CompressorStream,
                            Bzip2DecompressorStream)
    elseif compression == "gz" || compression == "gzip"
        compressor = ifelse(action == "compress",
                            GzipCompressorStream,
                            GzipDecompressorStream)
    elseif compression == "none"
        compressor = NoopStream  # no compression
    end
    return compressor
end


"""
    root_nodes(graph::DispatchGraph) ->

Return an iterable of all nodes in the graph with no input edges.
"""
function root_nodes(graph::DispatchGraph)
    imap(n->graph.nodes[n], filter(1:nv(graph.graph)) do node_index
        indegree(graph.graph, node_index) == 0
    end)
end
