###############################################################################
# TASK ########################################################################
###### The `task` field should not be accessed outside this section. ##########

function set_primal_start(task::Mosek.MSKtask, col::ColumnIndex, value::Float64)
    xx = Float64[value]
    for sol in [MSK_SOL_BAS, MSK_SOL_ITG]
        putxxslice(task, sol, col.value, col.value + Int32(1), xx)
    end
end
function set_primal_start(m::MosekModel, vi::MOI.VariableIndex, value::Float64)
    set_primal_start(m.task, mosek_index(m, vi), value)
end
function set_primal_start(task::Mosek.MSKtask, cols::ColumnIndices,
                          values::Vector{Float64})
    for sol in [MSK_SOL_BAS, MSK_SOL_ITG]
        if solutiondef(task, sol)
            xx = getxx(task, sol)
            xx[cols] = vals
            putxx(task, sol, xx)
        else
            xx = zeros(Float64, getnumvar(task))
            xx[cols] = vals
            putxx(task, sol, xx)
        end
    end
end
function set_primal_start(m::MosekModel, vis::Vector{MOI.VariableIndex},
                          values::Vector{Float64})
    if all(vi -> is_scalar(m, vi), vis)
        set_primal_start(m.task, columns(m, vis), values)
    else
        for (vi, value) in zip(vis, values)
            set_primal_start(m.task, mosek_index(m, vi), value)
        end
    end
end

###############################################################################
## INDEXING ###################################################################
###############################################################################

function variable_primal(m::MosekModel, N, col::ColumnIndex)
    return m.solutions[N].xx[col.value]
end
function variable_primal(m::MosekModel, N, mat::MatrixIndex)
    d = m.sd_dim[mat.matrix]
    r = d - mat.column + 1
    #   #entries full Δ       #entries right Δ      #entries above in lower Δ
    k = div((d + 1) * d, 2) - div((r + 1) * r, 2) + (mat.row - mat.column + 1)
    return m.solutions[N].barxj[mat.matrix][k]
end
function variable_primal(m::MosekModel, N, vi::MOI.VariableIndex)
    variable_primal(m, N, mosek_index(m, vi))
end

###############################################################################
# MOI #########################################################################
###############################################################################

#### objective
function MOI.get(m::MosekModel,attr::MOI.ObjectiveValue)
    return getprimalobj(m.task, m.solutions[attr.resultindex].whichsol)
end

MOI.get(m::MosekModel,attr::MOI.ObjectiveBound) = getdouinf(m.task,MSK_DINF_MIO_OBJ_BOUND)

MOI.get(m::MosekModel,attr::MOI.RelativeGap) = getdouinf(m.task,MSK_DINF_MIO_OBJ_REL_GAP)

MOI.get(m::MosekModel,attr::MOI.SolveTime) = getdouinf(m.task,MSK_DINF_OPTIMIZER_TIME)


# NOTE: The MOSEK interface currently only supports Min and Max
function MOI.get(model::MosekModel, ::MOI.ObjectiveSense)
    if model.feasibility
        return MOI.FEASIBILITY_SENSE
    else
        sense = getobjsense(model.task)
        if sense == MSK_OBJECTIVE_SENSE_MINIMIZE
            MOI.MIN_SENSE
        else
            MOI.MAX_SENSE
        end
    end
end

function MOI.set(model::MosekModel,
                 attr::MOI.ObjectiveSense,
                 sense::MOI.OptimizationSense)
    if sense == MOI.MIN_SENSE
        model.feasibility = false
        putobjsense(model.task,MSK_OBJECTIVE_SENSE_MINIMIZE)
    elseif sense == MOI.MAX_SENSE
        model.feasibility = false
        putobjsense(model.task,MSK_OBJECTIVE_SENSE_MAXIMIZE)
    else
        @assert sense == MOI.FEASIBILITY_SENSE
        model.feasibility = true
        putobjsense(model.task,MSK_OBJECTIVE_SENSE_MINIMIZE)
        MOI.set(model,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0))
    end
end

#### Solver/Solution information

function MOI.get(m::MosekModel,attr::MOI.SimplexIterations)
    miosimiter = getlintinf(m.task,MSK_LIINF_MIO_SIMPLEX_ITER)
    if miosimiter > 0
        Int(miosimiter)
    else
        Int(getintinf(m.task,MSK_IINF_SIM_PRIMAL_ITER) + getintinf(m.task,MSK_IINF_SIM_DUAL_ITER))
    end
end

function MOI.get(m::MosekModel,attr::MOI.BarrierIterations)
    miosimiter = getlintinf(m.task,MSK_LIINF_MIO_INTPNT_ITER)
    if miosimiter > 0
        Int(miosimiter)
    else
        Int(getintinf(m.task,MSK_IINF_INTPNT_ITER))
    end
end

function MOI.get(m::MosekModel,attr::MOI.NodeCount)
        Int(getintinf(m.task,MSK_IINF_MIO_NUM_BRANCH))
end

MOI.get(m::MosekModel,attr::MOI.RawSolver) = m.task

MOI.get(m::MosekModel,attr::MOI.ResultCount) = length(m.solutions)

#### Problem information

function MOI.get(model::MosekModel,
                 ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64},
                                           S}) where S <: ScalarLinearDomain
    F = MOI.ScalarAffineFunction{Float64}
    return count(id -> MOI.is_valid(model, MOI.ConstraintIndex{F, S}(id)),
                 allocatedlist(model.c_block))
end
function MOI.get(model::MosekModel,
                 ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{Float64},
                                               S}) where S <: ScalarLinearDomain
    F = MOI.ScalarAffineFunction{Float64}
    ids = filter(id -> MOI.is_valid(model, MOI.ConstraintIndex{F, S}(id)),
                 allocatedlist(model.c_block))
    return [MOI.ConstraintIndex{F, S}(id) for id in ids]
end
function MOI.get(model::MosekModel,
                 ::MOI.NumberOfConstraints{MOI.SingleVariable, S}) where S<:Union{ScalarLinearDomain,
                                                                                    ScalarIntegerDomain}
    F = MOI.SingleVariable
    return count(id -> MOI.is_valid(model, MOI.ConstraintIndex{F, S}(id)),
                 allocatedlist(model.x_block))
end
function MOI.get(model::MosekModel,
                 ::MOI.ListOfConstraintIndices{MOI.SingleVariable, S}) where S<:Union{ScalarLinearDomain,
                                                                                        ScalarIntegerDomain}
    F = MOI.SingleVariable
    ids = filter(id -> MOI.is_valid(model, MOI.ConstraintIndex{F, S}(id)),
                 allocatedlist(model.x_block))
    return [MOI.ConstraintIndex{F, S}(id) for id in ids]
end
function MOI.get(model::MosekModel,
                 ::MOI.NumberOfConstraints{MOI.VectorOfVariables, S}) where S<:VectorCone
    F = MOI.VectorOfVariables
    return count(id -> MOI.is_valid(model, MOI.ConstraintIndex{F, S}(id)),
                 1:getnumcone(model.task))
end
function MOI.get(model::MosekModel,
                 ::MOI.ListOfConstraintIndices{MOI.VectorOfVariables, S}) where S<:VectorCone
    F = MOI.VectorOfVariables
    ids = filter(id -> MOI.is_valid(model, MOI.ConstraintIndex{F, S}(id)),
                 1:getnumcone(model.task))
    return [MOI.ConstraintIndex{F, S}(id) for id in ids]
end
function MOI.get(model::MosekModel,
                 ::MOI.NumberOfConstraints{MOI.VectorOfVariables,
                                           MOI.PositiveSemidefiniteConeTriangle})
    # TODO this only works because deletion of PSD constraints is not supported yet
    return length(model.sd_dim)
end
function MOI.get(model::MosekModel,
                 ::MOI.ListOfConstraintIndices{MOI.VectorOfVariables,
                                               MOI.PositiveSemidefiniteConeTriangle})
    # TODO this only works because deletion of PSD constraints is not supported yet
    return [MOI.ConstraintIndex{MOI.VectorOfVariables,
                                MOI.PositiveSemidefiniteConeTriangle}(id) for id in 1:length(model.sd_dim)]
end

function MOI.get(model::MosekModel,
                 ::MOI.ListOfConstraints)
    list = Tuple{DataType, DataType}[]
    F = MOI.SingleVariable
    for D in [MOI.LessThan{Float64}, MOI.GreaterThan{Float64},
              MOI.EqualTo{Float64}, MOI.Interval{Float64},
              MOI.Integer, MOI.ZeroOne]
        if !iszero(MOI.get(model, MOI.NumberOfConstraints{F, D}()))
            push!(list, (F, D))
        end
    end
    F = MOI.ScalarAffineFunction{Float64}
    for D in [MOI.LessThan{Float64}, MOI.GreaterThan{Float64},
              MOI.EqualTo{Float64}, MOI.Interval{Float64}]
        if !iszero(MOI.get(model, MOI.NumberOfConstraints{F, D}()))
            push!(list, (F, D))
        end
    end
    F = MOI.VectorOfVariables
    for D in [MOI.SecondOrderCone, MOI.RotatedSecondOrderCone,
              # TODO reenable for Mosek 9
              #MOI.PowerCone{Float64}, MOI.DualPowerCone{Float64},
              #MOI.ExponentialCone, MOI.DualExponentialCone,
              MOI.PositiveSemidefiniteConeTriangle]
        if !iszero(MOI.get(model, MOI.NumberOfConstraints{F, D}()))
            push!(list, (F, D))
        end
    end
    return list
end

#### Warm start values

function MOI.set(m::MosekModel, attr::MOI.VariablePrimalStart,
                 v::MOI.VariableIndex, val::Float64)
    set_primal_start(m, v, val)
end

function MOI.set(m::MosekModel, ::MOI.VariablePrimalStart,
                 vis::Vector{MOI.VariableIndex}, values::Vector{Float64})
    set_primal_start(m, vis, values)
end

# function MOI.set(m::MosekModel,attr::MOI.ConstraintDualStart, vs::Vector{MOI.ConstraintIndex}, vals::Vector{Float64})
#     subj = columns(vs)

#     for sol in [ MSK_SOL_BAS, MSK_SOL_ITG ]
#         if solutiondef(m.task,sol)
#             xx = getxx(m.task,sol)
#             xx[subj] = vals
#             putxx(m.task,sol,xx)
#         else
#             xx = zeros(Float64,getnumvar(m.task))
#             xx[subj] = vals
#             putxx(m.task,sol,xx)
#         end
#     end
# end

#### Variable solution values

function MOI.get(m::MosekModel, attr::MOI.VariablePrimal, vi::MOI.VariableIndex)
    return variable_primal(m, attr.N, vi)
end
function MOI.get!(output::Vector{Float64}, m::MosekModel,
                  attr::MOI.VariablePrimal, vs::Vector{MOI.VariableIndex})
    @assert eachindex(output) == eachindex(vs)
    for i in eachindex(output)
        output[i] = MOI.get(m, attr, vs[i])
    end
end
function MOI.get(m::MosekModel, attr::MOI.VariablePrimal,
                 vs::Vector{MOI.VariableIndex})
    output = Vector{Float64}(undef, length(vs))
    MOI.get!(output, m, attr, vs)
    return output
end

#### Constraint solution values

function MOI.get(
    m     ::MosekModel,
    attr  ::MOI.ConstraintPrimal,
    ci  ::MOI.ConstraintIndex{MOI.SingleVariable,D}) where D
    col = column(m, _variable(ci))
    return m.solutions[attr.N].xx[col.value]
end

# Semidefinite domain for a variable
function MOI.get!(
    output::Vector{Float64},
    m     ::MosekModel,
    attr  ::MOI.ConstraintPrimal,
    ci  ::MOI.ConstraintIndex{MOI.VectorOfVariables,
                              MOI.PositiveSemidefiniteConeTriangle})
    whichsol = getsolcode(m,attr.N)
    output[1:length(output)] = reorder(getbarxj(m.task, whichsol, ci.value),
                                       MOI.PositiveSemidefiniteConeTriangle)
end

# Any other domain for variable vector
function MOI.get!(
    output::Vector{Float64},
    m     ::MosekModel,
    attr  ::MOI.ConstraintPrimal,
    ci  ::MOI.ConstraintIndex{MOI.VectorOfVariables,D}) where D
    cols = columns(m, ci)
    output[1:length(output)] = reorder(m.solutions[attr.N].xx[cols.values], D)
end

function MOI.get(m     ::MosekModel,
                 attr  ::MOI.ConstraintPrimal,
                 ci  ::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},D}) where D
    cid = ref2id(ci)
    subi = getindex(m.c_block,cid)
    return m.solutions[attr.N].xc[subi]
end

function _variable_constraint_dual(sol::MosekSolution, col::ColumnIndex,
                                   ::Type{<:Union{MOI.Interval{Float64}, MOI.EqualTo{Float64}}})
    return sol.slx[col.value] - sol.sux[col.value]
end
function _variable_constraint_dual(sol::MosekSolution, col::ColumnIndex, ::Type{MOI.GreaterThan{Float64}})
    return sol.slx[col.value]
end
function _variable_constraint_dual(sol::MosekSolution, col::ColumnIndex, ::Type{MOI.LessThan{Float64}})
    return -sol.sux[col.value]
end
function MOI.get(m::MosekModel, attr::MOI.ConstraintDual,
                 ci::MOI.ConstraintIndex{MOI.SingleVariable, S}) where S <: ScalarLinearDomain
    col = column(m, _variable(ci))
    dual = _variable_constraint_dual(m.solutions[attr.N], col, S)
    if getobjsense(m.task) == MSK_OBJECTIVE_SENSE_MINIMIZE
        return dual
    else
        return -dual
    end
end

getsolcode(m::MosekModel, N) = m.solutions[N].whichsol

# The dual or primal of an SDP variable block is returned in lower triangular
# form but the constraint is in upper triangular form.
function reorder(x, ::Type{MOI.PositiveSemidefiniteConeTriangle})
    n = div(isqrt(1 + 8length(x)) - 1, 2)
    @assert length(x) == MOI.dimension(MOI.PositiveSemidefiniteConeTriangle(n))
    y = similar(x)
    k = 0
    for j in 1:n, i in j:n
        k += 1
        y[div((i - 1) * i, 2) + j] = x[k]

    end
    @assert k == length(x)
    return y
end

function reorder(x, ::Type{<:Union{MOI.ExponentialCone,
                                   MOI.DualExponentialCone}})
    return [x[3], x[2], x[1]]
end
reorder(x, ::Type{<:VectorCone}) = x


# Semidefinite domain for a variable
function MOI.get!(
    output::Vector{Float64},
    m     ::MosekModel,
    attr  ::MOI.ConstraintDual,
    ci  ::MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.PositiveSemidefiniteConeTriangle})
    whichsol = getsolcode(m,attr.N)
    # It is in fact a real constraint and cid is the id of an ordinary constraint
    dual = reorder(getbarsj(m.task, whichsol, ci.value),
                   MOI.PositiveSemidefiniteConeTriangle)
    if (getobjsense(m.task) == MSK_OBJECTIVE_SENSE_MINIMIZE)
        output[1:length(output)] .= dual
    else
        output[1:length(output)] .= -dual
    end
end

# Any other domain for variable vector
function MOI.get!(
    output::Vector{Float64},
    m     ::MosekModel,
    attr  ::MOI.ConstraintDual,
    ci  ::MOI.ConstraintIndex{MOI.VectorOfVariables,D}) where D

    xcid = ref2id(ci)
    @assert(xcid > 0)

    cols = columns(m, ci)

    idx = reorder(1:length(output), D)

    if (getobjsense(m.task) == MSK_OBJECTIVE_SENSE_MINIMIZE)
        output[idx] = m.solutions[attr.N].snx[cols.values]
    else
        output[idx] = -m.solutions[attr.N].snx[cols.values]
    end
end

function MOI.get(m     ::MosekModel,
                 attr  ::MOI.ConstraintDual,
                 ci  ::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},D}) where D

    cid = ref2id(ci)
    subi = getindex(m.c_block, cid)

    if getobjsense(m.task) == MSK_OBJECTIVE_SENSE_MINIMIZE
        m.solutions[attr.N].y[subi]
    else
        - m.solutions[attr.N].y[subi]
    end
end

solsize(m::MosekModel, ::MOI.ConstraintIndex{<:MOI.AbstractScalarFunction}) = 1
function solsize(m::MosekModel, ci::MOI.ConstraintIndex{MOI.VectorOfVariables})
    return getconeinfo(m.task, ci.value)[3]
end
function solsize(m::MosekModel,
                 ci::MOI.ConstraintIndex{MOI.VectorOfVariables,
                                         MOI.PositiveSemidefiniteConeTriangle})
    d = m.sd_dim[ci.value]
    return MOI.dimension(MOI.PositiveSemidefiniteConeTriangle(d))
end

function MOI.get(m::MosekModel,
                 attr::Union{MOI.ConstraintPrimal, MOI.ConstraintDual},
                 ci::MOI.ConstraintIndex{<:MOI.AbstractVectorFunction})
    cid = ref2id(ci)
    output = Vector{Float64}(undef, solsize(m, ci))
    MOI.get!(output, m, attr, ci)
    return output
end

#### Status codes
function MOI.get(m::MosekModel,attr::MOI.TerminationStatus)
    if     m.trm === nothing
        MOI.OPTIMIZE_NOT_CALLED
    elseif m.trm == MSK_RES_OK
        if any(sol -> sol.solsta == MSK_SOL_STA_PRIM_INFEAS_CER, m.solutions)
            MOI.INFEASIBLE
        elseif any(sol -> sol.solsta == MSK_SOL_STA_DUAL_INFEAS_CER,
                   m.solutions)
            MOI.DUAL_INFEASIBLE
        else
            MOI.OPTIMAL
        end
    elseif m.trm == MSK_RES_TRM_MAX_ITERATIONS
        MOI.ITERATION_LIMIT
    elseif m.trm == MSK_RES_TRM_MAX_TIME
        MOI.TIME_LIMIT
    elseif m.trm == MSK_RES_TRM_OBJECTIVE_RANGE
        MOI.OBJECTIVE_LIMIT
    elseif m.trm == MSK_RES_TRM_MIO_NEAR_REL_GAP
        MOI.ALMOST_OPTIMAL
    elseif m.trm == MSK_RES_TRM_MIO_NEAR_ABS_GAP
        MOI.ALMOST_OPTIMAL
    elseif m.trm == MSK_RES_TRM_MIO_NUM_RELAXS
        MOI.OTHER_LIMIT
    elseif m.trm == MSK_RES_TRM_MIO_NUM_BRANCHES
        MOI.NODE_LIMIT
    elseif m.trm == MSK_RES_TRM_NUM_MAX_NUM_INT_SOLUTIONS
        MOI.SOLUTION_LIMIT
    elseif m.trm == MSK_RES_TRM_STALL
        MOI.SLOW_PROGRESS
    elseif m.trm == MSK_RES_TRM_USER_CALLBACK
        MOI.INTERRUPTED
    elseif m.trm == MSK_RES_TRM_MAX_NUM_SETBACKS
        MOI.OTHER_LIMIT
    elseif m.trm == MSK_RES_TRM_NUMERICAL_PROBLEM
        MOI.SLOW_PROGRESS
    elseif m.trm == MSK_RES_TRM_INTERNAL
        MOI.OTHER_ERROR
    elseif m.trm == MSK_RES_TRM_INTERNAL_STOP
        MOI.OTHER_ERROR
    else
        MOI.OTHER_ERROR
    end
end

function MOI.get(m::MosekModel, attr::MOI.PrimalStatus)
    solsta = m.solutions[attr.N].solsta
    if     solsta == MSK_SOL_STA_UNKNOWN
        MOI.UNKNOWN_RESULT_STATUS
    elseif solsta == MSK_SOL_STA_OPTIMAL
        MOI.FEASIBLE_POINT
    elseif solsta == MSK_SOL_STA_PRIM_FEAS
        MOI.FEASIBLE_POINT
    elseif solsta == MSK_SOL_STA_DUAL_FEAS
        MOI.UNKNOWN_RESULT_STATUS
    elseif solsta == MSK_SOL_STA_PRIM_AND_DUAL_FEAS
        MOI.FEASIBLE_POINT
    elseif solsta == MSK_SOL_STA_PRIM_INFEAS_CER
        MOI.NO_SOLUTION
    elseif solsta == MSK_SOL_STA_DUAL_INFEAS_CER
        MOI.INFEASIBILITY_CERTIFICATE
    elseif solsta == MSK_SOL_STA_PRIM_ILLPOSED_CER
        MOI.NO_SOLUTION
    elseif solsta == MSK_SOL_STA_DUAL_ILLPOSED_CER
        MOI.REDUCTION_CERTIFICATE
    elseif solsta == MSK_SOL_STA_INTEGER_OPTIMAL
        MOI.FEASIBLE_POINT
    else
        MOI.UNKNOWN_RESULT_STATUS
    end
end

function MOI.get(m::MosekModel,attr::MOI.DualStatus)
    solsta = m.solutions[attr.N].solsta
    if     solsta == MSK_SOL_STA_UNKNOWN
        MOI.UNKNOWN_RESULT_STATUS
    elseif solsta == MSK_SOL_STA_OPTIMAL
        MOI.FEASIBLE_POINT
    elseif solsta == MSK_SOL_STA_PRIM_FEAS
        MOI.UNKNOWN_RESULT_STATUS
    elseif solsta == MSK_SOL_STA_DUAL_FEAS
        MOI.FEASIBLE_POINT
    elseif solsta == MSK_SOL_STA_PRIM_AND_DUAL_FEAS
        MOI.FEASIBLE_POINT
    elseif solsta == MSK_SOL_STA_PRIM_INFEAS_CER
        MOI.INFEASIBILITY_CERTIFICATE
    elseif solsta == MSK_SOL_STA_DUAL_INFEAS_CER
        MOI.NO_SOLUTION
    elseif solsta == MSK_SOL_STA_PRIM_ILLPOSED_CER
        MOI.REDUCTION_CERTIFICATE
    elseif solsta == MSK_SOL_STA_DUAL_ILLPOSED_CER
        MOI.NO_SOLUTION
    elseif solsta == MSK_SOL_STA_INTEGER_OPTIMAL
        MOI.NO_SOLUTION
    else
        MOI.UNKNOWN_RESULT_STATUS
    end
end
