# Similar to JuMP/test/solvers.jl

function try_import(name::Symbol)
    try
        @eval import $name
        return true
    catch e
        return false
    end
end

mos = try_import(:Mosek)
csd = try_import(:CSDP)
scs = try_import(:SCS)

isscs(solver) = occursin("SCSSolver", string(typeof(solver)))

# Semidefinite solvers
sdp_solvers = Any[]
# Need at least Mosek 8 for sosdemo3 to pass; see:
# https://github.com/JuliaOpt/Mosek.jl/issues/92
# and at least Mosek 8.0.0.41 for sosdemo6 to pass; see:
# https://github.com/JuliaOpt/Mosek.jl/issues/98
mos && push!(sdp_solvers, Mosek.MosekSolver(LOG=0))
# Currently, need to create a file param.csdp to avoid printing, see https://github.com/JuliaOpt/CSDP.jl/issues/15
csd && push!(sdp_solvers, CSDP.CSDPSolver(printlevel=0))
iscsdp(solver) = occursin("CSDP", string(typeof(solver)))
# Need 54000 iterations for sosdemo3 to pass on Linux 64 bits
# With 55000, sosdemo3 passes for every platform except Windows 64 bits on AppVeyor
scs && push!(sdp_solvers, SCS.SCSSolver(eps=1e-5, max_iters=60000, verbose=0))
