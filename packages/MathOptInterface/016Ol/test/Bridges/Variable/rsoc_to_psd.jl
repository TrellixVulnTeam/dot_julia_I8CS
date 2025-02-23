using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MathOptInterface.Test
const MOIU = MathOptInterface.Utilities
const MOIB = MathOptInterface.Bridges

include("../utilities.jl")

mock = MOIU.MockOptimizer(MOIU.Model{Float64}())
config = MOIT.TestConfig()

bridged_mock = MOIB.Variable.RSOCtoPSD{Float64}(mock)

@testset "RSOC4" begin
    mock.optimize! = (mock::MOIU.MockOptimizer) -> MOIU.mock_optimize!(mock, [1.0, 1.0, 2.0, 1.0, 0.0, 2.0],
        (MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64})  => [0.25],
        (MOI.SingleVariable, MOI.EqualTo{Float64})  => [-0.5],
        (MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}) => [-1.0],
        (MOI.VectorOfVariables, MOI.PositiveSemidefiniteConeTriangle) => [[1.0, -0.5, 0.25, -0.5, 0.25, 0.25]])
    mock.eval_variable_constraint_dual = false
    MOIT.rotatedsoc4test(bridged_mock, config)
    mock.eval_variable_constraint_dual = true

    @testset "Test mock model" begin
        var_names = ["Q$i$j" for j in 1:3 for i in 1:j]
        MOI.set(
            mock, MOI.VariableName(),
            MOI.get(mock, MOI.ListOfVariableIndices()), var_names)
        psd = MOI.get(mock, MOI.ListOfConstraintIndices{
            MOI.VectorOfVariables, MOI.PositiveSemidefiniteConeTriangle}())
        @test length(psd) == 1
        MOI.set(mock, MOI.ConstraintName(), psd[1], "psd")
        off_diag = MOI.get(mock, MOI.ListOfConstraintIndices{
            MOI.SingleVariable, MOI.EqualTo{Float64}}())
        @test length(off_diag) == 1
        MOI.set(mock, MOI.ConstraintName(), off_diag[1], "off_diag23")
        diag = MOI.get(mock, MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}())
        @test length(diag) == 1
        MOI.set(mock, MOI.ConstraintName(), diag[1], "diag33")
        c = MOI.get(mock, MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}())
        @test length(c) == 1
        MOI.set(mock, MOI.ConstraintName(), c[1], "c")

        s = """
        variables: Q11, Q12, Q13, Q22, Q23, Q33
        psd: [Q11, Q12, Q22, Q13, Q23, Q33] in MathOptInterface.PositiveSemidefiniteConeTriangle(3)
        off_diag23: Q23 == 0.0
        diag33: Q22 + -1.0Q33 == 0.0
        c: Q11 + 0.5Q22 <= 2.0
        maxobjective: Q12 + Q13
        """
        model = MOIU.Model{Float64}()
        MOIU.loadfromstring!(model, s)
        MOIU.test_models_equal(mock, model, var_names, ["psd", "off_diag23", "diag33", "c"])
    end

    @testset "Test bridged model" begin
        var_names = ["t", "u", "x", "y"]
        MOI.set(
            bridged_mock, MOI.VariableName(),
            MOI.get(bridged_mock, MOI.ListOfVariableIndices()), var_names)
        rsoc = MOI.get(bridged_mock, MOI.ListOfConstraintIndices{
            MOI.VectorOfVariables, MOI.RotatedSecondOrderCone}())
        @test length(rsoc) == 1
        MOI.set(bridged_mock, MOI.ConstraintName(), rsoc[1], "rsoc")
        c = MOI.get(bridged_mock, MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}())
        @test length(c) == 1
        MOI.set(bridged_mock, MOI.ConstraintName(), c[1], "c")

        s = """
        variables: t, u, x, y
        rsoc: [t, u, x, y] in MathOptInterface.RotatedSecondOrderCone(4)
        c: t + u <= 2.0
        maxobjective: x + y
        """
        model = MOIU.Model{Float64}()
        MOIU.loadfromstring!(model, s)
        MOIU.test_models_equal(bridged_mock, model, var_names, ["rsoc", "c"])
    end


    @testset "Delete" begin
        v = MOI.get(bridged_mock, MOI.ListOfVariableIndices())
        @test length(v) == 4

        message = string("Cannot delete variable as it is constrained with other",
                         " variables in a `MOI.VectorOfVariables`.")
        for i in 1:4
            err = MOI.DeleteNotAllowed(v[i], message)
            @test_throws err MOI.delete(bridged_mock, v[i])
        end

        test_delete_bridged_variables(bridged_mock, v, MOI.RotatedSecondOrderCone, 4, (
            (MOI.VectorOfVariables, MOI.PositiveSemidefiniteConeTriangle, 0),
            (MOI.SingleVariable, MOI.EqualTo{Float64}, 0),
            (MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}, 0),
        ))
    end
end
