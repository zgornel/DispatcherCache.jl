"""
    node_hash(node, key2hash)

Calculates and returns the hash corresponding to a `Dispatcher` task graph
node i.e. `DispatchNode` using the hashes of its dependencies, input arguments
and source code of the function associated to the `node`. Any available hashes
are taken from `key2hash`.
"""
function node_hash(node::DispatchNode, key2hash::Dict{T,String}) where T
    hash_code = source_hash(node)
    hash_arguments = arg_hash(node)
    hash_dependencies = dep_hash(node, key2hash)

    node_hash = __hash(join(hash_code, hash_arguments, hash_dependencies))
    subgraph_hash = Dict("code" => hash_code,
                         "args" => hash_arguments,
                         "deps" => hash_dependencies)
    return node_hash, subgraph_hash
end


"""
    source_hash(node)

Hashes the lowered representation of the source code of the function
associated with `node`. Useful for `Op` nodes, the other node types
do not have any associated source code.
"""
source_hash(node::Op) = begin
    f = node.func
    code = join(code_lowered(f)[1].code, "\n")
    return __hash(code)
end

source_hash(node::DispatchNode) = __hash(nothing)


"""
    arg_hash(node)

Hash the data arguments (in certain cases configuration fields) of the
dispatch `node`.
"""
arg_hash(node::Op) = begin
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

arg_hash(node::DataNode) = __hash(node.data)

arg_hash(node::IndexNode) = __hash(node.index)

arg_hash(node::DispatchNode) = __hash(nothing)


"""
    dep_hash(node, key2hash)

Hash the dispatch node dependencies of `node` using their existing hashes if possible.
"""
dep_hash(node::DispatchNode, key2hash) = begin
    h = __hash(nothing)
    nodes = dependencies(node)
    if isempty(nodes)
        return __hash(h)
    else
        for node in nodes
            h *= get(key2hash, node, dep_hash(node, key2hash))
        end
        return __hash(h)
    end
end


"""
    __hash(something)

Return a hexadecimal string corresponding to the hash of sum
of the hashes of the value and type of `something`.
"""
function __hash(something)
    h = hash(hash(typeof(something)) + hash(something))
    return string(h, base=16)
end
