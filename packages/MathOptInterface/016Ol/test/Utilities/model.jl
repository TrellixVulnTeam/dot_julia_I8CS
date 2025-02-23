using Test
import MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities

# We need to test this in a module at the top level because it can't be defined
# in a testset. If it runs without error, then we're okay.
module TestExternalModel
    using MathOptInterface
    struct NewSet <: MathOptInterface.AbstractScalarSet end
    struct NewFunction <: MathOptInterface.AbstractScalarFunction end
    Base.copy(::NewFunction) = NewFunction()
    Base.copy(::NewSet) = NewSet()
    MathOptInterface.Utilities.@model(ExternalModel,
        (MathOptInterface.ZeroOne, NewSet,),
        (),
        (),
        (),
        (NewFunction,),
        (),
        (),
        ()
    )
end

@testset "External @model" begin
    model = TestExternalModel.ExternalModel{Float64}()
    c = MOI.add_constraint(
        model, TestExternalModel.NewFunction(), TestExternalModel.NewSet())
    @test typeof(c) == MOI.ConstraintIndex{TestExternalModel.NewFunction,
        TestExternalModel.NewSet}
    c2 = MOI.add_constraint(
        model, TestExternalModel.NewFunction(), MOI.ZeroOne())
    @test typeof(c2) ==
        MOI.ConstraintIndex{TestExternalModel.NewFunction, MOI.ZeroOne}
end

@testset "Setting lower/upper bound twice" begin
    @testset "flag_to_set_type" begin
        err = ErrorException("Invalid flag `0x11`.")
        T = Int
        @test_throws err MOIU.flag_to_set_type(0x11, T)
        @test MOIU.flag_to_set_type(0x10, T) == MOI.Integer
        @test MOIU.flag_to_set_type(0x20, T) == MOI.ZeroOne
    end
    @testset "$T" for T in [Int, Float64]
        model = MOIU.Model{T}()
        MOIT.set_lower_bound_twice(model, T)
        MOIT.set_upper_bound_twice(model, T)
    end
end

@testset "Name test" begin
    MOIT.nametest(MOIU.Model{Float64}())
end

@testset "Valid test" begin
    MOIT.validtest(MOIU.Model{Float64}())
end

@testset "Delete test" begin
    MOIT.delete_test(MOIU.Model{Float64}())
end

@testset "Empty test" begin
    MOIT.emptytest(MOIU.Model{Float64}())
end

@testset "supports_constraint test" begin
    MOIT.supports_constrainttest(MOIU.Model{Float64}(), Float64, Int)
    MOIT.supports_constrainttest(MOIU.Model{Int}(), Int, Float64)
end

@testset "OrderedIndices" begin
    MOIT.orderedindicestest(MOIU.Model{Float64}())
end

@testset "Continuous Linear tests" begin
    config = MOIT.TestConfig(solve=false)
    exclude = ["partial_start"] # Model doesn't support VariablePrimalStart.
    MOIT.contlineartest(MOIU.Model{Float64}(), config, exclude)
end

@testset "Continuous Conic tests" begin
    config = MOIT.TestConfig(solve=false)
    MOIT.contconictest(MOIU.Model{Float64}(), config)
end

@testset "Quadratic functions" begin

    model = MOIU.Model{Int}()

    x, y = MOI.add_variables(model, 2)
    @test 2 == @inferred MOI.get(model, MOI.NumberOfVariables())

    f1 = MOI.ScalarQuadraticFunction(MOI.ScalarAffineTerm.([3], [x]), MOI.ScalarQuadraticTerm.([1, 2, 3], [x, y, x], [x, y, y]), 7)
    c1 = MOI.add_constraint(model, f1, MOI.Interval(-1, 1))

    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.ScalarQuadraticFunction{Int},MOI.Interval{Int}}())
    @test (@inferred MOI.get(model, MOI.ListOfConstraintIndices{MOI.ScalarQuadraticFunction{Int},MOI.Interval{Int}}())) == [c1]

    f2 = MOI.VectorQuadraticFunction(MOI.VectorAffineTerm.([1, 2, 2], MOI.ScalarAffineTerm.([3, 1, 2], [x, x, y])), MOI.VectorQuadraticTerm.([1, 1, 2], MOI.ScalarQuadraticTerm.([1, 2, 3], [x, y, x], [x, y, y])), [7, 3, 4])
    c2 = MOI.add_constraint(model, f2, MOI.PositiveSemidefiniteConeTriangle(3))

    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorQuadraticFunction{Int},MOI.PositiveSemidefiniteConeTriangle}())
    @test (@inferred MOI.get(model, MOI.ListOfConstraintIndices{MOI.VectorQuadraticFunction{Int},MOI.PositiveSemidefiniteConeTriangle}())) == [c2]

    loc = MOI.get(model, MOI.ListOfConstraints())
    @test length(loc) == 2
    @test (MOI.VectorQuadraticFunction{Int},MOI.PositiveSemidefiniteConeTriangle) in loc
    @test (MOI.VectorQuadraticFunction{Int},MOI.PositiveSemidefiniteConeTriangle) in loc

    f3 = MOIU.modify_function(f1, MOI.ScalarConstantChange(9))
    f3 = MOIU.modify_function(f3, MOI.ScalarCoefficientChange(y, 2))

    @test !(MOI.get(model, MOI.ConstraintFunction(), c1) ≈ f3)
    MOI.set(model, MOI.ConstraintFunction(), c1, f3)
    @test MOI.get(model, MOI.ConstraintFunction(), c1) ≈ f3

    f4 = MOI.VectorAffineFunction(MOI.VectorAffineTerm.([1, 1, 2], MOI.ScalarAffineTerm.([2, 4, 3], [x, y, y])), [5, 7])
    c4 = MOI.add_constraint(model, f4, MOI.SecondOrderCone(2))
    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Int},MOI.SecondOrderCone}())

    f5 = MOI.VectorOfVariables([x])
    c5 = MOI.add_constraint(model, f5, MOI.RotatedSecondOrderCone(1))
    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.RotatedSecondOrderCone}())

    f6 = MOI.VectorAffineFunction(MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([2, 9], [x, y])), [6, 8])
    c6 = MOI.add_constraint(model, f6, MOI.SecondOrderCone(2))
    @test 2 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Int},MOI.SecondOrderCone}())

    f7 = MOI.VectorOfVariables([x, y])
    c7 = MOI.add_constraint(model, f7, MOI.Nonpositives(2))
    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.Nonpositives}())

    f8 = MOI.VectorOfVariables([x, y])
    c8 = MOI.add_constraint(model, f8, MOI.SecondOrderCone(2))
    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.SecondOrderCone}())

    loc1 = MOI.get(model, MOI.ListOfConstraints())
    loc2 = Vector{Tuple{DataType, DataType}}()
    function _pushloc(constrs::Vector{MOIU.ConstraintEntry{F, S}}) where {F, S}
        if !isempty(constrs)
            push!(loc2, (F, S))
        end
    end
    MOIU.broadcastcall(_pushloc, model)
    for loc in (loc1, loc2)
        @test length(loc) == 6
        @test (MOI.VectorQuadraticFunction{Int},MOI.PositiveSemidefiniteConeTriangle) in loc
        @test (MOI.VectorQuadraticFunction{Int},MOI.PositiveSemidefiniteConeTriangle) in loc
        @test (MOI.VectorOfVariables,MOI.RotatedSecondOrderCone) in loc
        @test (MOI.VectorAffineFunction{Int},MOI.SecondOrderCone) in loc
        @test (MOI.VectorOfVariables,MOI.Nonpositives) in loc
    end

    @test MOI.is_valid(model, c4)
    MOI.delete(model, c4)
    @test !MOI.is_valid(model, c4)

    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorAffineFunction{Int},MOI.SecondOrderCone}())
    @test MOI.get(model, MOI.ConstraintFunction(), c6).constants == f6.constants

    message = string("Cannot delete variable as it is constrained with other",
                     " variables in a `MOI.VectorOfVariables`.")
    err = MOI.DeleteNotAllowed(y, message)
    @test_throws err MOI.delete(model, y)

    @test MOI.is_valid(model, c8)
    MOI.delete(model, c8)
    @test !MOI.is_valid(model, c8)
    @test 0 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.SecondOrderCone}())

    MOI.delete(model, y)

    f = MOI.get(model, MOI.ConstraintFunction(), c2)
    @test f.affine_terms == MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([3, 1], [x, x]))
    @test f.quadratic_terms == MOI.VectorQuadraticTerm.([1], MOI.ScalarQuadraticTerm.([1], [x], [x]))
    @test f.constants == [7, 3, 4]

    f = MOI.get(model, MOI.ConstraintFunction(), c6)
    @test f.terms == MOI.VectorAffineTerm.([1], MOI.ScalarAffineTerm.([2], [x]))
    @test f.constants == [6, 8]

    @test 1 == @inferred MOI.get(model, MOI.NumberOfConstraints{MOI.VectorOfVariables,MOI.Nonpositives}())
    @test [c7] == @inferred MOI.get(model, MOI.ListOfConstraintIndices{MOI.VectorOfVariables,MOI.Nonpositives}())

    f =  MOI.get(model, MOI.ConstraintFunction(), c7)
    @test f.variables == [x]

    s =  MOI.get(model, MOI.ConstraintSet(), c7)
    @test MOI.dimension(s) == 1
end

# We create a new function and set to test catching errors if users create their
# own sets and functions
struct FunctionNotSupportedBySolvers <: MOI.AbstractScalarFunction
    x::MOI.VariableIndex
end
struct SetNotSupportedBySolvers <: MOI.AbstractSet end
@testset "Default fallbacks" begin
    @testset "set" begin
        model = MOIU.Model{Float64}()
        x = MOI.add_variable(model)
        func = convert(MOI.ScalarAffineFunction{Float64}, MOI.SingleVariable(x))
        c = MOI.add_constraint(model, func, MOI.LessThan(0.0))
        @test !MOI.supports_constraint(model, FunctionNotSupportedBySolvers, SetNotSupportedBySolvers)

        # set of different type
        @test_throws Exception MOI.set(model, MOI.ConstraintSet(), c, MOI.GreaterThan(0.0))
        # set not implemented
        @test_throws Exception MOI.set(model, MOI.ConstraintSet(), c, SetNotSupportedBySolvers())

        # function of different type
        @test_throws Exception MOI.set(model, MOI.ConstraintFunction(), c, MOI.VectorOfVariables([x]))
        # function not implemented
        @test_throws Exception MOI.set(model, MOI.ConstraintFunction(), c, FunctionNotSupportedBySolvers(x))
    end
end
