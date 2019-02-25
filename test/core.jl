# Useful constants
const REGEX_EXEC_STORE = r"getfield\(DispatcherCache, Symbol\(\"#exec_store_wrapper#[0-9]+\"\)\)"
const REGEX_LOAD = r"getfield\(DispatcherCache, Symbol\(\"#loading_wrapper#[0-9]+\"\)\)"
const TMPDIR = tempdir()
const COMPRESSION = "none"
const EXECUTOR = AsyncExecutor()

using DispatcherCache: get_node, node_hash, load_hashchain

# Useful functions
function get_indexed_result_value(graph, idx; executor=AsyncExecutor())
    _result = run!(executor, graph)
    idx > 0 && idx <= length(_result) && return fetch(_result[idx].result.value)
    return nothing
end

function get_labeled_result_value(graph, label; executor=AsyncExecutor())
    _result = run!(executor, graph)
    for r in _result
        rlabel = r.result.value.label
        rval = r.result.value
        rlabel == label && return fetch(rval)
    end
    return nothing
end

function get_result_value(graph; executor=AsyncExecutor())
    _result = run!(executor, graph)
    return fetch(_result[1].result.value)
end


raw"""
Generates a Dispatcher task graph of the form below,
which will be used as a basis for the functional
testing of the module:

                     O top(..)
                 ____|____
                /         \
               d1          O baz(..)
                  _________|________
                 /                  \
                O boo(...)           O goo(...)
         _______|_______         ____|____
        /       |       \       /    |    \
       O        O        O     O     |     O
     foo(.) bar(.)    baz(.)  foo(.) v6  bar(.)
      |         |        |     |           |
      |         |        |     |           |
      v1       v2       v3    v4          v5
"""
function example_of_dispatch_graph(modifiers=Dict{String,Function}())
    # Default functions
    _foo(argument) = argument
    _bar(argument) = argument + 2
    _baz(args...) = sum(args)
    _boo(args...) = length(args) + sum(args)
    _goo(args...) = sum(args) + 1
    _top(argument, argument2) = argument - argument2

	# Apply modifiers if any
	local foo, bar, baz, boo, goo, top
	for fname in ["foo", "bar", "baz", "boo", "goo", "top"]
		foo = get(modifiers, "foo", _foo)
		bar = get(modifiers, "bar", _bar)
		baz = get(modifiers, "baz", _baz)
		boo = get(modifiers, "boo", _boo)
		goo = get(modifiers, "goo", _goo)
		top = get(modifiers, "top", _top)
	end

    # Graph (for the function definitions above)
    v1 = 1
    v2 = 2
    v3 = 3
    v4 = 0
    v5 = -1
    v6 = -2
    d1 = -3
    foo1 = @op foo(v1); set_label!(foo1, "foo1")
    foo2 = @op foo(v4); set_label!(foo2, "foo2")
    bar1 = @op bar(v2); set_label!(bar1, "bar1")
    bar2 = @op bar(v5); set_label!(bar2, "bar2")
    baz1 = @op baz(v3); set_label!(baz1, "baz1")
    boo1 = @op boo(foo1, bar1, baz1); set_label!(boo1, "boo1")
    goo1 = @op goo(foo2, bar2, v6); set_label!(goo1, "goo1")
    baz2 = @op baz(boo1, goo1); set_label!(baz2, "baz2")
    top1 = @op top(d1, baz2); set_label!(top1, "top1")

    graph = DispatchGraph(top1)
    top_key = "top1"
    return graph, top_key
end


@testset "Dispatch graph generation" begin
    graph, top_key = example_of_dispatch_graph()
    top_key_idx = [i for i in 1:length(graph.nodes)
                   if graph.nodes[i].label == top_key][1]
    @test graph isa DispatchGraph
    @test get_indexed_result_value(graph, top_key_idx) == -14
    @test get_labeled_result_value(graph, top_key) == -14
end


@testset "First run" begin
    mktempdir(TMPDIR) do cachedir
        # Make dispatch graph
        graph, top_key = example_of_dispatch_graph()
        # Get endpoints
        endpoints = [get_node(graph, top_key)]
        # Add hash cache and update graph
        updates = add_hash_cache!(graph, endpoints,
                                  compression=COMPRESSION,
                                  cachedir=cachedir)

        # Test that all nodes have been wrapped (EXEC-STORE)
        for i in length(graph.nodes)
            node = graph.nodes[i]
            node isa Op && @test occursin(REGEX_EXEC_STORE, string(node.func))
        end

        # Run the task graph
        @test get_labeled_result_value(graph, top_key) == -14

        # Test that files exist
        hcfile = joinpath(cachedir, DispatcherCache.DEFAULT_HASHCHAIN_FILENAME)
        hcdir = joinpath(cachedir, DispatcherCache.DEFAULT_HASHCACHE_DIR)
        @test isfile(hcfile)
        @test isdir(hcdir)
        hashchain = open(hcfile, "r") do fid
            JSON.parse(fid)
        end

        # Test the hashchain keys
        @test hashchain["compression"] == COMPRESSION
        @test hashchain["version"] == 1  # dummy test, version not used so far
        # Test that each key corresponds to a cache file name
        cachefiles = readdir(hcdir)
        nodehashes = keys(hashchain["hashchain"])
        @test length(nodehashes) == length(cachefiles)
        for file in readdir(hcdir)
            _hash = split(file, ".")[1]
            @test _hash in nodehashes
        end
    end
end


@testset "Second run" begin
    mktempdir(TMPDIR) do cachedir
        # Make dispatch graph
        graph, top_key = example_of_dispatch_graph()
        # Get endpoints
        endpoints = [get_node(graph, top_key)]
        # Make a first run (generate cache, do not modify graph)
        result = run!(EXECUTOR, graph, endpoints,
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == -14

        # Add hash cache and update graph
        updates = add_hash_cache!(graph, endpoints,
                                  compression=COMPRESSION,
                                  cachedir=cachedir)

        # Test that all nodes have been wrapped (LOAD)
        for i in length(graph.nodes)
            node = graph.nodes[i]
            node isa Op && @test occursin(REGEX_LOAD, string(node.func))
        end

        # Make a second run
        @test get_labeled_result_value(graph, top_key) == -14
    end
end


@testset "Node changes" begin
    mktempdir(TMPDIR) do cachedir
        # Make dispatch graph
        graph, top_key = example_of_dispatch_graph()
        # Get endpoints
        endpoints = [get_node(graph, top_key)]
        # Make a first run (generate cache, do not modify graph)
        result = run!(EXECUTOR, graph, endpoints,
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == -14

        # Create altered versions of initial graph
        new_top(argument, argument2) = argument - argument2 - 1
        g1, _ = example_of_dispatch_graph(Dict("top" => new_top))
        g1data = ("top1", ("top1",), -15)

        new_goo(args...) = sum(args) + 2
        g2, _ = example_of_dispatch_graph(Dict("goo" => new_goo))
        g2data = ("goo1", ("baz2", "top1"), -15)

        for (graph, (key, impacted_keys, result)) in zip((g1, g2), (g1data, g2data))
            # Get enpoints for new graphs
            endpoints = [get_node(graph, top_key)]
            # Add hash cache and update graph
            updates = add_hash_cache!(graph, endpoints,
                                      compression=COMPRESSION,
                                      cachedir=cachedir)

            # Test that impacted nodes are wrapped in EXEC-STORES,
            # non impacted ones in LOADS
            for i in length(graph.nodes)
                node = graph.nodes[i]
                node isa Op && !(node.label in impacted_keys) &&
                    @test occursin(REGEX_LOAD, string(node.func))
                node isa Op && node.label in impacted_keys &&
                    @test occursin(REGEX_EXEC_STORE, string(node.func))
            end

            # Make a second run
            @test get_labeled_result_value(graph, top_key) == result
        end
    end
end


@testset "Exec only nodes" begin
    mktempdir(TMPDIR) do cachedir
        EXEC_ONLY_KEY = "boo1"
        # Make dispatch graph
        graph, top_key = example_of_dispatch_graph()
        # Get endpoints
        endpoints = [get_node(graph, top_key)]
        # Get uncacheable nodes
        uncacheable = [get_node(graph, EXEC_ONLY_KEY)]
        # Make a first run (generate cache, do not modify graph)
        result = run!(EXECUTOR, graph, endpoints,
                      uncacheable,  # node "boo1" is uncachable
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == -14
        hashchain = load_hashchain(cachedir)

        # Test that node hash is not in hashchain and no cache
        # file exists in the cache directory
        nh = node_hash(get_node(graph, EXEC_ONLY_KEY), Dict{String, String}())
        @test !(nh in keys(hashchain))
        @test !(join(nh, ".bin") in
                readdir(joinpath(cachedir, DispatcherCache.DEFAULT_HASHCACHE_DIR)))

        # Make a new graph that has the "goo1" node modified
        new_goo(args...) = sum(args) + 2
        new_graph, top_key = example_of_dispatch_graph(Dict("goo"=>new_goo))

        # Check the final result:
        # The output of node "boo1" is needed at node "baz2"
        # because "goo1" was modified. A matching result indicates
        # that the "boo1" dependencies were loaded and the node
        # executed correctly which is the desired behaviour
        # in such cases.
        endpoints = [get_node(new_graph, top_key)]
        uncacheable = [get_node(new_graph, EXEC_ONLY_KEY)]
        result = run!(EXECUTOR, new_graph, endpoints,
                      uncacheable,
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == -15
    end
end


@testset "Cache deletion" begin
    mktempdir(TMPDIR) do cachedir
        # Make dispatch graph
        graph, top_key = example_of_dispatch_graph()
        # Get endpoints
        endpoints = [get_node(graph, top_key)]
        # Make a first run (generate cache, do not modify graph)
        result = run!(EXECUTOR, graph, endpoints,
                      compression=COMPRESSION,
                      cachedir=cachedir)
        # Remove cache
        hashcachedir = joinpath(cachedir, DispatcherCache.DEFAULT_HASHCACHE_DIR)
        rm(hashcachedir, recursive=true, force=true)
        @test !isdir(hashcachedir)
        # Make a second run (no hash cache)
        result = run!(EXECUTOR, graph, endpoints,
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == -14
    end
end


@testset "Identical nodes" begin
    v1 = 1
    foo(x) = x + 1
    bar(x, y) = x + y
    foo1 = @op foo(v1); set_label!(foo1, "foo1")
    foo2 = @op foo(v1); set_label!(foo1, "foo2")
    bar1 = @op bar(foo1, foo2); set_label!(bar1, "bar1")
    g = DispatchGraph(bar1)

    mktempdir(TMPDIR) do cachedir
        hcfile = joinpath(cachedir, DispatcherCache.DEFAULT_HASHCHAIN_FILENAME)
        hcdir = joinpath(cachedir, DispatcherCache.DEFAULT_HASHCACHE_DIR)

        # Run the first time
        result = run!(EXECUTOR, g, ["bar1"],
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == 4

        hashchain = load_hashchain(cachedir)
        cachefiles = readdir(hcdir)
        nodehashes = keys(hashchain)
        # Test that 2 hashes / cache files exist (corresponding to "foo" and "bar")
        @test length(nodehashes) == length(cachefiles) == 2

        # Run the second time
        result = run!(EXECUTOR, g, ["bar1"], cachedir=cachedir)
        @test fetch(result[1].result.value) == 4
    end
end


raw"""
Generates a Dispatcher task graph of the form below,
which will be used as a basis for the functional
testing of the module. This dispatch graph contains
all subtypes of `DispatchNode`.

                     O top(..)
                 ____|____
                /         \
               O           O
          DataNode(1)  IndexNode(...,1)
                           |
                           O
                      CollectNode(...)
                  _________|________
                 /                  \
                O foo(...)           O bar(...)
                |                    |
                |                    |
                v1                   v2
"""
function example_of_dispatch_graph_w_mixed_nodes(modifiers=Dict{String,Function}())
    # Default functions
    _foo(argument) = argument
    _bar(argument) = argument + 2
    _top(argument, argument2) = argument - argument2

	# Apply modifiers if any
	local foo, bar, top
	for fname in ["foo", "bar", "top"]
		foo = get(modifiers, "foo", _foo)
		bar = get(modifiers, "bar", _bar)
		top = get(modifiers, "top", _top)
	end

    # Graph (for the function definitions above)
    v1 = 1
    v2 = 2
    foo1 = @op foo(v1); set_label!(foo1, "foo1")
    bar1 = @op bar(v2); set_label!(bar1, "bar1")
    d1 = DataNode(1)
    col1 = CollectNode([foo1, bar1])
    idx1 = IndexNode(col1, 1)
    top1 = @op top(d1, idx1); set_label!(top1, "top1")

    graph = DispatchGraph(top1)
    return graph, top1
end


@testset "Dispatch graph generation (mixed nodes)" begin
    graph, top_node = example_of_dispatch_graph_w_mixed_nodes()
    @test graph isa DispatchGraph
    @test get_result_value(graph) == 0
end


@testset "First run (mixed nodes)" begin
    mktempdir(TMPDIR) do cachedir
        # Make dispatch graph
        graph, top_node = example_of_dispatch_graph_w_mixed_nodes()
        # Get endpoints
        endpoints = [get_node(graph, top_node)]
        # Add hash cache and update graph
        updates = add_hash_cache!(graph, endpoints,
                                  compression=COMPRESSION,
                                  cachedir=cachedir)

        # Test that all nodes have been wrapped (EXEC-STORE)
        for i in length(graph.nodes)
            node = graph.nodes[i]
            node isa Op && @test occursin(REGEX_EXEC_STORE, string(node.func))
        end

        # Run the task graph
        @test get_result_value(graph) == 0

        # The other checks are omitted
        # ...
    end
end


@testset "Second run" begin
    mktempdir(TMPDIR) do cachedir
        # Make dispatch graph
        graph, top_node = example_of_dispatch_graph_w_mixed_nodes()
        # Get endpoints
        endpoints = [get_node(graph, top_node)]
        # Make a first run (generate cache, do not modify graph)
        result = run!(EXECUTOR, graph, endpoints,
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == 0

        # Add hash cache and update graph
        updates = add_hash_cache!(graph, endpoints,
                                  compression=COMPRESSION,
                                  cachedir=cachedir)

        # Test that all nodes have been wrapped (LOAD)
        for i in length(graph.nodes)
            node = graph.nodes[i]
            node isa Op && @test occursin(REGEX_LOAD, string(node.func))
        end

        # Make a second run
        @test get_result_value(graph) == 0
    end
end
