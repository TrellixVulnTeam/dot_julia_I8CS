using Test, YaoBase, YaoBlocks, BitBasis, YaoArrayRegister, Random
using StatsBase: mean

@testset "measure ghz" begin
    # GHZ state
    st = normalize!(ArrayReg(bit"0000") + ArrayReg(bit"1111"))
    Random.seed!(1234)

    # measure it at 1, 2
    # should collapse to 0000 or 1111 since entangled
    g = Measure(4; locs=(1, 2))
    st |> g

    @test g.results[1] == 0 ? st.state[end] == 0 : st.state[1] == 0
end

@testset "collapseto" begin
    Random.seed!(1234)

    st = rand_state(5; nbatch=3)
    g = Measure(5; locs=(1, 2), collapseto=bit"00011")
    st |> g
    for k in 1:32
        if !(st.state[k] ≈ 0.0)
            @test all(BitStr64{5}(k-1)[1:2] .== 1)
        end
    end
    @test Measure(5; locs=(1, 2), collapseto=0b0011).collapseto isa BitStr64{5}
end

@testset "error handling" begin
    @test_throws ErrorException Measure(5; locs=(1, 2), collapseto=bit"00011", remove=true)
    @test_throws ErrorException mat(Measure(5; locs=(1, 2), collapseto=bit"00011"))
end


@testset "op-measures" begin
    Random.seed!(1234)

    reg = rand_state(6, nbatch=10)
    op = repeat(3, X)

    # measure!
    reg2 = reg |> copy
    res = measure!(op, reg2, 2:4)
    res2 = measure!(op, reg2, 2:4)
    @test size(res) == (10,)
    @test res2 == res

    # measure_collapseto!
    reg2 = reg |> copy
    res = measure_collapseto!(op, reg2, 2:4)
    reg2 |> repeat(6, H, 2:4)
    res2 = measure_collapseto!(op, reg2, 2:4)
    @test size(res) == (10,) == size(res2)
    @test all(res2 .== 1)

    # measure_remove!
    reg2 = reg |> copy
    res = measure_remove!(op, reg2, 2:4)
    reg2 |> repeat(3, H, 2:3)
    @test size(res) == (10,)
    @test nqubits(reg2) == 3

    reg = repeat(ArrayReg(ComplexF64[1,-1]/sqrt(2.0)), 10)
    @test measure!(X, reg) |> mean ≈ -1
    reg = repeat(ArrayReg(ComplexF64[1.0,0]), 1000)
    @test abs(measure!(X, reg) |> mean) < 0.1
end

@testset "op-measures" begin
    reg = rand_state(8; nbatch=32)
    op = repeat(5, X, 1:5)

    # measure!
    reg2 = reg |> copy
    res = measure!(op, reg2, 2:6)
    res2 = measure!(op, reg2, 2:6)
    @test size(res) == (32,)
    @test res2 == res

    # measure_collapseto!
    reg2 = reg |> copy
    res = measure_collapseto!(op, reg2, 2:6)
    reg2 |> repeat(8, H, 2:6)
    res2 = measure_collapseto!(op, reg2, 2:6)
    @test size(res) == (32,) == size(res2)
    @test all(res2 .== 1)

    # measure_remove!
    reg2 = reg |> copy
    res = measure_remove!(op, reg2, 2:6)
    @test size(res) == (32,)

    reg = repeat(ArrayReg([1,-1+0im]/sqrt(2.0)), 10)
    @test measure!(X, reg) |> mean ≈ -1
    reg = repeat(ArrayReg([1.0,0+0im]), 1000)
    @test abs(measure!(X, reg) |> mean) < 0.1
end
