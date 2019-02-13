function add_hashes!(dsk::DispatchGraph,
                     cacheable::Vector{T}=T[],
                     no_cache_keys::Vector{T}=T[];
                     compression::String=DEFAULT_COMPRESSION,
                     cachedir::String=DEFAULT_CACHE_DIR
                    ) where T<:Union{<:DispatchNode, <:AbstractString}
    if isempty(cacheable)
        @warn "No keys to hash, will not process dispatch graph."
        return nothing
    end

    hashchain = load_hashchain(cachedir, compression=compression)
    allkeys = get_keys(dsk, T)  # all keys in the dispatch graph
    work = Deque{T}()                          # keys to be traversed
    for key in allkeys
        push!(work, key)
    end
    solved = Set()                             # keys of computable tasks
    dependencies = get_dependencies(dsk, T)
    keyhashmaps = Dict{T, String}()            # key=>hash mapping
    #newdsk = copy(dsk)                         # output
    hashes_to_store = Set{String}()            # list of hashes that correspond
                                               #   to keys whose output will be stored
    while !isempty(work)
        key = popfirst!(work)
        deps = dependencies[key]
        @info "Checking $key ..."
        if isempty(deps) || issubset(deps, solved)
            # Node is solvable
            @info "$key is solvable!"
            push!(solved, key)
            node = get_node(dsk, key)          # The node is always a DispatchNode
            _hash_node, _hash_comp = get_hash(node, keyhashmaps)
            keyhashmaps[key] = _hash_node
            skipcache = key in no_cache_keys
            # Wrap nodes
            if _hash_node in keys(hashchain) && !skipcache &&
                    !(_hash_node in hashes_to_store)
                # Hash match and output cacheable
                @info "$key: Hash match, LOAD"
                # TODO: Wrap
                ######################################
                label = node.label
                idx = dsk.nodes[node]
                dsk.nodes[idx] = Op(()->return 100)
                dsk.nodes[idx].label = label
                ######################################
                # TODO: Wrap
            elseif _hash_node in keys(hashchain) && skipcache
                # Hash match and output *non-cachable*
                @info "$key: Hash match, EXEC"
                # TODO: Wrap
            else
                # Hash miss
                @info "$key: Hash miss, EXEC (and potentially STORE)"
                hashchain[_hash_node] = _hash_comp
                push!(hashes_to_store, _hash_node)
                # Write some stuff into the file
                # TODO: Wrap
                open(joinpath(cachedir, "cache", _hash_node*".bin"), "w+") do fid
                    write(fid, _hash_node)
                end
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
