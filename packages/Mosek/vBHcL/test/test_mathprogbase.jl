module TestMathProgBase

import Mosek.MosekMathProgSolverInterface
import Mosek
using MathProgBase
using Test


mpbdir = dirname(dirname(pathof(MathProgBase)))

include(joinpath(mpbdir,"test","linprog.jl"))
include(joinpath(mpbdir,"test","mixintprog.jl"))
include(joinpath(mpbdir,"test","quadprog.jl"))
include(joinpath(mpbdir,"test","nlp.jl"))
include(joinpath(mpbdir,"test","conicinterface.jl"))
include(joinpath(mpbdir,"test","linproginterface.jl"))


function test_mathprogbase(solver)
    @testset "linprog" begin
        linprogtest(solver)
    end

    @testset "mip" begin
        mixintprogtest(solver)
    end


    @testset "qp" begin
        quadprogtest(solver)
        #qpdualtest(solver)
        #socptest(solver)
    end

    @testset "nlp" begin
        #nlptest(solver)
        #nlptest_nohessian(solver)
        #convexnlptest(solver)
        #rosenbrocktest(solver)
    end

    @testset "conic" begin
        coniclineartest(solver, duals=true)
        # Test conic fallback for LPs
        #coniclineartest(solver, duals=true)
    end

    @testset "linproginterface" begin
        linprogsolvertest(solver)
        linprogsolvertestextra(solver)
        # Test LP fallback for conics
        linprogsolvertest(solver)
    end

end

test_mathprogbase(Mosek.MosekSolver(QUIET = true, fallback = "mosek://solve.mosek.com"))

end
