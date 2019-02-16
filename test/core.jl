# Useful constants
const regex_exec_store = r"getfield\(DispatcherCache, Symbol\(\"#exec_store_wrapper#[0-9]+\"\)\)"
const regex_load = r"getfield\(DispatcherCache, Symbol\(\"#loading_wrapper#[0-9]+\"\)\)"


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
    return graph
end


@testset "DAG Generation" begin
    graph = example_of_dispatch_graph()
    @test graph isa DispatchGraph
    @test get_indexed_result_value(graph, 1) == -14
    @test get_labeled_result_value(graph, "top1") == -14
end


@testset "First run" begin

end
