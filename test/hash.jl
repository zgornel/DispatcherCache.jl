using DispatcherCache: node_hash, source_hash, arg_hash, dep_hash, __hash

@testset "Hashing" begin
    # Low level
    v = 1
    @test __hash(v) == string(hash(hash(typeof(v)) + hash(v)), base=16)

    # Generate some functions and ops
    foo(x, y) = x + y
    bar(x) = x
    another_foo(x, y) = begin
        # some comment
        x+y
    end
    yet_another_foo(x,y) = x + y + 1 - 1

    bar1 = @op bar(10)
    foo1 = @op foo(bar1, 10)
    foo2 = @op another_foo(1, 2)
    foo3 = @op yet_another_foo(1, 2)

    # Source
    @test source_hash(foo1) == source_hash(foo2)
    @test source_hash(foo1) != source_hash(foo3)

    # Arguments
    @test arg_hash(foo2) == arg_hash(foo3)
    @test arg_hash(foo1) == arg_hash(bar1)
    @test arg_hash(bar1) == __hash(hash(nothing) + hash(10) + hash(Int))

    # Dependencies
    k2h = Dict{Op, String}()
    hash_bar1, _ = node_hash(bar1, k2h)
    @test dep_hash(foo1, k2h) == __hash(__hash(nothing) * hash_bar1)

    # Entire node
    h_src = source_hash(foo1)
    h_arg = arg_hash(foo1)
    h_dep = dep_hash(foo1, k2h)
    @test node_hash(foo1, k2h) ==
        (__hash(join(h_src, h_arg, h_dep)),
         Dict("code" => h_src, "args" => h_arg, "deps" => h_dep))
end

