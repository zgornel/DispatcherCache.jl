# Useful constants
const REGEX_EXEC_STORE = r"getfield\(DispatcherCache, Symbol\(\"#exec_store_wrapper#[0-9]+\"\)\)"
const REGEX_LOAD = r"getfield\(DispatcherCache, Symbol\(\"#loading_wrapper#[0-9]+\"\)\)"
const TMPDIR = tempdir()
const COMPRESSION = "none"
const EXECUTOR = AsyncExecutor()

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
function example_of_dispatch_graph()
    # Functions
    foo(argument) = argument
    bar(argument) = argument + 2
    baz(args...) = sum(args)
    boo(args...) = length(args) + sum(args)
    goo(args...) = sum(args) + 1
    top(argument, argument2) = argument - argument2

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


@testset "DAG Generation" begin
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
        endpoints = [DispatcherCache.get_node(graph, top_key)]
        # Add hash cache and update graph
        updates = add_hash_cache!(graph, endpoints,
                                  compression=COMPRESSION,
                                  cachedir=cachedir)

        # Test that all keys have been wrapped (EXEC-STORE)
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
        endpoints = [DispatcherCache.get_node(graph, top_key)]
        # Make a first run (generate cache, do not modify graph)
        result = run!(EXECUTOR, graph, endpoints,
                      compression=COMPRESSION,
                      cachedir=cachedir)
        @test fetch(result[1].result.value) == -14

        # Add hash cache and update graph
        updates = add_hash_cache!(graph, endpoints,
                                  compression=COMPRESSION,
                                  cachedir=cachedir)

        # Test that all keys have been wrapped (LOAD)
        for i in length(graph.nodes)
            node = graph.nodes[i]
            node isa Op && @test occursin(REGEX_LOAD, string(node.func))
        end

        # Make a second run
        @test get_labeled_result_value(graph, top_key) == -14
    end
end
