using OMEinsum: tsetdiff, tunique

@testset "utils" begin
    @test tsetdiff((1,2,3), (2,)) == [1,3]
    @test tunique((1,2,3,3,)) == [1,2,3]
    @test asarray(3) isa Array
    @test asarray(3, randn(3,3)) isa Array
    @test asarray(randn(3,3)) isa Array
end
