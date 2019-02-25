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

# Examples
```julia
julia> using DispatcherCache: source_hash
       f(x) = x + 1
       g(x) = begin
               #comment
               x + 1
              end
       node_f = @op f(1)
       node_g = @op g(10)
       # Test
	   source_hash(node_f) == source_hash(node_g)
# true
```
"""
source_hash(node::Op) = begin
    f = node.func
    local code
    try
        code = join(code_lowered(f)[1].code, "\n")
    catch
        code = get_label(node)
        @warn "Cannot hash code for node $(code) (using label)."
    end
    return __hash(code)
end

source_hash(node::DispatchNode) = __hash(nothing)


"""
    arg_hash(node)

Hash the data arguments (in certain cases configuration fields) of the
dispatch `node`.

# Examples
```julia
julia> using DispatcherCache: arg_hash, __hash
       f(x) = println("\$x")
       arg = "argument"
       node = @op f(arg)
       arg_hash(node)
# "d482b7b1b5357c33"

julia> arg_hash(node) == __hash(hash(nothing) + hash(arg) + hash(typeof(arg)))
# true
```
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
            h *= get(key2hash, node, node_hash(node, key2hash)[1])
        end
        return __hash(h)
    end
end


"""
    __hash(something)

Return a hexadecimal string corresponding to the hash of sum
of the hashes of the value and type of `something`.

# Examples
```julia
julia> using DispatcherCache: __hash
       __hash([1,2,3])
# "f00429a0d65eb7cb"
```
"""
function __hash(something)
    h = hash(hash(typeof(something)) + hash(something))
    return string(h, base=16)
end
