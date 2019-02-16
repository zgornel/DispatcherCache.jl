# DispatcherCache.jl

A task persistency mechanism based on hash-graphs for [Dispatcher.jl](https://github.com/invenia/Dispatcher.jl). Based on [graphchain](https://github.com/radix-ai/graphchain), [(commit baa1c3f)](https://github.com/radix-ai/graphchain/tree/baa1c3fa94da86bd6e495c64fe63c12b36d50a1a).

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Build Status](https://travis-ci.org/zgornel/DispatcherCache.jl.svg?branch=master)](https://travis-ci.org/zgornel/DispatcherCache.jl)
[![Coverage Status](https://coveralls.io/repos/github/zgornel/DispatcherCache.jl/badge.svg?branch=master)](https://coveralls.io/github/zgornel/DispatcherCache.jl?branch=master)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://zgornel.github.io/DispatcherCache.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/DispatcherCache.jl/dev)


## Installation
```bash
git clone "https://zgornel.github.com/DispatcherCache.jl"
```
or, from inside Julia,
```
] add https://zgornel.github.com/DispatcherCache.jl#master
```


## Minimal example
```julia
julia> using Dispatcher
       using DispatcherCache

       # Some functions
       foo(x) = begin sleep(1); x end
       bar(x) = begin sleep(1); x+1 end
       baz(x,y) = begin sleep(1); x-y end

       # Make a dispatch graph out of some operations
       op1 = @op foo(1)
       op2 = @op bar(2)
       op3 = @op baz(op1, op2)
       D = DispatchGraph(op3)
# DispatchGraph({3, 2} directed simple Int64 graph,
# NodeSet(DispatchNode[
# Op(DeferredFuture at (1,1,241),baz,"baz"),
# Op(DeferredFuture at (1,1,239),foo,"foo"),
# Op(DeferredFuture at (1,1,240),bar,"bar")]))

julia> # First run, writes results to disk (lasts 2 seconds)
       result_node = [op3]  # the node for which we want results
       cachedir = "./__cache__"  # directory does not exist
       @time r = run!(AsyncExecutor(), D, result_node, cachedir=cachedir)
       println("result (first run) = \$(fetch(r[1].result.value))")
# [info | Dispatcher]: Executing 3 graph nodes.
# [info | Dispatcher]: Node 1 (Op<baz, Op<foo>, Op<bar>>): running.
# [info | Dispatcher]: Node 2 (Op<foo, Int64>): running.
# [info | Dispatcher]: Node 3 (Op<bar, Int64>): running.
# [info | Dispatcher]: Node 2 (Op<foo, Int64>): complete.
# [info | Dispatcher]: Node 3 (Op<bar, Int64>): complete.
# [info | Dispatcher]: Node 1 (Op<baz, Op<foo>, Op<bar>>): complete.
# [info | Dispatcher]: All 3 nodes executed.
#   2.029992 seconds (11.53 k allocations: 1.534 MiB)
# result (first run) = -2

julia> # Secod run, loads directly the result from ./__cache__
       @time r = run!(AsyncExecutor(), D, [op3], cachedir=cachedir)
       println("result (second run) = \$(fetch(r[1].result.value))")
# [info | Dispatcher]: Executing 1 graph nodes.
# [info | Dispatcher]: Node 1 (Op<baz>): running.
# [info | Dispatcher]: Node 1 (Op<baz>): complete.
# [info | Dispatcher]: All 1 nodes executed.
#   0.005257 seconds (2.57 k allocations: 478.359 KiB)
# result (second run) = -2

julia> readdir(cachedir)
# 2-element Array{String,1}:
#  "cache"
#  "hashchain.json"
```


## Features
To keep track with the latest features, please consult [NEWS.md](https://github.com/zgornel/DispatcherCache.jl/blob/master/NEWS.md) and the [documentation](https://zgornel.github.io/DispatcherCache.jl/dev).


## License

This code has an MIT license and therefore it is free.


## Reporting Bugs

Please [file an issue](https://github.com/zgornel/DispatcherCache.jl/issues/new) to report a bug or request a feature.


## References

[1] [Dispatcher.jl documentation](https://invenia.github.io/Dispatcher.jl/stable/)

[2] [Graphchain documentation](https://graphchain.readthedocs.io/en/latest/)
