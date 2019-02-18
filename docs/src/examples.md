# Usage examples

The following examples will attempt to illustrate the basic functionality of the package and how it can be employed to speed up computationally demanding processing pipelines. Although toy problems are being used, it should be straightforward to apply the concepts illustrated below to real-word applications. More subtle properties of the caching mechanism are exemplified in the [unit tests](https://github.com/zgornel/DispatcherCache.jl/blob/master/test/core.jl) of the package.

## Basics

Let us begin by defining a simple computational task graph with three nodes
```@repl index
using Dispatcher, DispatcherCache

# Some functions
foo(x) = begin sleep(3); x end;
bar(x) = begin sleep(3); x+1 end;
baz(x,y) = begin sleep(2); x-y end;

op1 = @op foo(1);
op2 = @op bar(2);
op3 = @op baz(op1, op2);
G = DispatchGraph(op3)
```

Once the dispatch graph `G` is defined, one can calculate the result for any of the nodes contained in it. For example, for the top or _leaf_ node `op3`,
```@repl index
extract(r) = fetch(r[1].result.value);  # gets directly the result value
result = run!(AsyncExecutor(), G);  # automatically runs op3
println("result (normal run) = $(extract(result))")
```

Using the `DispatcherCache` `run!` method caches all intermediary node outputs to a specified directory
```@repl index
cachedir = mktempdir()  # cache temporary directory
@time result = run!(AsyncExecutor(), G, [op3], cachedir=cachedir);
println("result (caching run) = $(extract(result))")
```

!!! note

    The `run!` method with caching support needs explicit specification of the output nodes (the `Dispatcher` one executes directly the leaf nodes of the graph). Through this, one may choose to cache only a subgraph of the full dispatch graph.

After the first _cached_ run, one can verify that the cache related files exist on disk
```@repl index
readdir(cachedir)
readdir(joinpath(cachedir, "cache"))
```

Running the computation a second time will result in loading the last - cached - result, operation noticeable through the fact that the time needed decreased. 
```@repl index
@time result = run!(AsyncExecutor(), G, [op3], cachedir=cachedir);
println("result (cached run) = $(extract(result))")
```

The cache can be cleaned up by simply removing the cache directory.
```@repl index
rm(cachedir, recursive=true, force=true)
```
If the cache does not exist anymore, a new call of `run!(::Executor, G, [op3], cachedir=cachedir)` will re-create the cache by running each node.

!!! note

    In the examples above, the functions `foo`, `bar` and `baz` use the `sleep` function to simulate longer running computations. This is useful to both illustrate the concept presented and to overcome the pre-compilation overhead that occurs then calling the `run!` method.
