```@meta
CurrentModule=DispatcherCache
```

# Introduction

DispatcherCache is a task persistency mechanism for [Dispatcher.jl](https://github.com/invenia/Dispatcher.jl) computational task graphs. It is based on [graphchain](https://github.com/radix-ai/graphchain) which is a caching mechanism for [Dask](https://dask.org) task graphs.

## Motivation
[Dispatcher.jl](https://github.com/invenia/Dispatcher.jl) represents a convenient way of organizing i.e. scheduling complex computational workflows for asynchronous or parallel execution. Running the same workflow multiple times is not uncommon, albeit with varying input parameters or data. Depending on the type of tasks being executed, in many cases, some of the tasks remain unchanged between distinct runs: the same function is being called on identical input arguments.

`DispatcherCache` provides a way of re-using the output of the nodes in the dispatch graph, as long as their state did not change to some unobserved one. By state it is understood the source code, arguments and the node dependencies associated with the nodes. If the state of some node does change between two consecutive executions of the graph, only the node and the nodes impacted downstream (towards the leafs of the graph) are actually executed. The nodes whose state did not change are in effect (not practice) pruned from the graph, with the exception of the ones that are dependencies of nodes that have to be re-executed due to state change.

## Installation

In the shell of choice, using
```
$ git clone https://github.com/zgornel/DispatcherCache.jl
```
or, inside Julia
```
] add DispatcherCache
```
and for the latest `master` branch,
```
] add https://github.com/zgornel/DispatcherCache.jl#master
```
