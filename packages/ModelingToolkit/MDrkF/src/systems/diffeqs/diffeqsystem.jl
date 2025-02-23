export ODESystem, ODEFunction


using Base: RefValue


isintermediate(eq::Equation) = !(isa(eq.lhs, Operation) && isa(eq.lhs.op, Differential))

function flatten_differential(O::Operation)
    @assert is_derivative(O) "invalid differential: $O"
    is_derivative(O.args[1]) || return (O.args[1], O.op.x, 1)
    (x, t, order) = flatten_differential(O.args[1])
    isequal(t, O.op.x) || throw(ArgumentError("non-matching differentials on lhs: $t, $(O.op.x)"))
    return (x, t, order + 1)
end


struct DiffEq  # dⁿx/dtⁿ = rhs
    x::Variable
    n::Int
    rhs::Expression
end
function to_diffeq(eq::Equation)
    isintermediate(eq) && throw(ArgumentError("intermediate equation received"))
    (x, t, n) = flatten_differential(eq.lhs)
    (isa(t, Operation) && isa(t.op, Variable) && isempty(t.args)) ||
        throw(ArgumentError("invalid independent variable $t"))
    (isa(x, Operation) && isa(x.op, Variable) && length(x.args) == 1 && isequal(first(x.args), t)) ||
        throw(ArgumentError("invalid dependent variable $x"))
    return t.op, DiffEq(x.op, n, eq.rhs)
end
Base.:(==)(a::DiffEq, b::DiffEq) = isequal((a.x, a.n, a.rhs), (b.x, b.n, b.rhs))

"""
$(TYPEDEF)

A system of ordinary differential equations.

# Fields
* `eqs` - The ODEs defining the system.

# Examples

```
using ModelingToolkit

@parameters t σ ρ β
@variables x(t) y(t) z(t)
@derivatives D'~t

eqs = [D(x) ~ σ*(y-x),
       D(y) ~ x*(ρ-z)-y,
       D(z) ~ x*y - β*z]

de = ODESystem(eqs)
```
"""
struct ODESystem <: AbstractSystem
    """The ODEs defining the system."""
    eqs::Vector{DiffEq}
    """Independent variable."""
    iv::Variable
    """Dependent (state) variables."""
    dvs::Vector{Variable}
    """Parameter variables."""
    ps::Vector{Variable}
    """
    Jacobian matrix. Note: this field will not be defined until
    [`calculate_jacobian`](@ref) is called on the system.
    """
    jac::RefValue{Matrix{Expression}}
    """
    Wfact matrix. Note: this field will not be defined until
    [`generate_factorized_W`](@ref) is called on the system.
    """
    Wfact::RefValue{Matrix{Expression}}
    """
    Wfact_t matrix. Note: this field will not be defined until
    [`generate_factorized_W`](@ref) is called on the system.
    """
    Wfact_t::RefValue{Matrix{Expression}}
end

function ODESystem(eqs)
    reformatted = to_diffeq.(eqs)

    ivs = unique(r[1] for r ∈ reformatted)
    length(ivs) == 1 || throw(ArgumentError("one independent variable currently supported"))
    iv = first(ivs)

    deqs = [r[2] for r ∈ reformatted]

    dvs = [deq.x for deq ∈ deqs]
    ps = filter(vars(deq.rhs for deq ∈ deqs)) do x
        x.known & !isequal(x, iv)
    end |> collect

    ODESystem(deqs, iv, dvs, ps)
end

function ODESystem(deqs::AbstractVector{DiffEq}, iv, dvs, ps)
    jac = RefValue(Matrix{Expression}(undef, 0, 0))
    Wfact   = RefValue(Matrix{Expression}(undef, 0, 0))
    Wfact_t = RefValue(Matrix{Expression}(undef, 0, 0))
    ODESystem(deqs, iv, dvs, ps, jac, Wfact, Wfact_t)
end

function ODESystem(deqs::AbstractVector{<:Equation}, iv, dvs, ps)
    _dvs = [deq.op for deq ∈ dvs]
    _iv = iv.op
    _ps = [p.op for p ∈ ps]
    ODESystem(getindex.(to_diffeq.(deqs),2), _iv, _dvs, _ps)
end

function _eq_unordered(a, b)
    length(a) === length(b) || return false
    n = length(a)
    idxs = Set(1:n)
    for x ∈ a
        idx = findfirst(isequal(x), b)
        idx === nothing && return false
        idx ∈ idxs      || return false
        delete!(idxs, idx)
    end
    return true
end
Base.:(==)(sys1::ODESystem, sys2::ODESystem) =
    _eq_unordered(sys1.eqs, sys2.eqs) && isequal(sys1.iv, sys2.iv) &&
    _eq_unordered(sys1.dvs, sys2.dvs) && _eq_unordered(sys1.ps, sys2.ps)
# NOTE: equality does not check cached Jacobian

independent_variables(sys::ODESystem) = Set{Variable}([sys.iv])
dependent_variables(sys::ODESystem) = Set{Variable}(sys.dvs)
parameters(sys::ODESystem) = Set{Variable}(sys.ps)


function calculate_jacobian(sys::ODESystem)
    isempty(sys.jac[]) || return sys.jac[]  # use cached Jacobian, if possible
    rhs = [eq.rhs for eq ∈ sys.eqs]

    iv = sys.iv()
    dvs = [dv(iv) for dv ∈ sys.dvs]

    jac = expand_derivatives.(calculate_jacobian(rhs, dvs))
    sys.jac[] = jac  # cache Jacobian
    return jac
end

struct ODEToExpr
    sys::ODESystem
end
function (f::ODEToExpr)(O::Operation)
    if isa(O.op, Variable)
        isequal(O.op, f.sys.iv) && return O.op.name  # independent variable
        O.op ∈ f.sys.dvs        && return O.op.name  # dependent variables
        isempty(O.args)         && return O.op.name  # 0-ary parameters
        return build_expr(:call, Any[O.op.name; f.(O.args)])
    end
    return build_expr(:call, Any[O.op; f.(O.args)])
end
(f::ODEToExpr)(x) = convert(Expr, x)

function generate_jacobian(sys::ODESystem, dvs = sys.dvs, ps = sys.ps)
    jac = calculate_jacobian(sys)
    return build_function(jac, dvs, ps, (sys.iv.name,), ODEToExpr(sys))
end

function generate_function(sys::ODESystem, dvs = sys.dvs, ps = sys.ps)
    rhss = [deq.rhs for deq ∈ sys.eqs]
    dvs′ = [clean(dv) for dv ∈ dvs]
    ps′ = [clean(p) for p ∈ ps]
    return build_function(rhss, dvs′, ps′, (sys.iv.name,), ODEToExpr(sys))
end

function calculate_factorized_W(sys::ODESystem, simplify=true)
    isempty(sys.Wfact[]) || return (sys.Wfact[],sys.Wfact_t[])

    jac = calculate_jacobian(sys)
    gam = Variable(:gam; known = true)()

    W = - LinearAlgebra.I + gam*jac
    Wfact = lu(W, Val(false), check=false).factors

    if simplify
        Wfact = simplify_constants.(Wfact)
    end

    W_t = - LinearAlgebra.I/gam + jac
    Wfact_t = lu(W_t, Val(false), check=false).factors
    if simplify
        Wfact_t = simplify_constants.(Wfact_t)
    end
    sys.Wfact[] = Wfact
    sys.Wfact_t[] = Wfact_t

    (Wfact,Wfact_t)
end

function generate_factorized_W(sys::ODESystem, vs = sys.dvs, ps = sys.ps, simplify=true)
    (Wfact,Wfact_t) = calculate_factorized_W(sys,simplify)
    siz = size(Wfact)
    constructor = :(x -> begin
                        A = SMatrix{$siz...}(x)
                        StaticArrays.LU(LowerTriangular( SMatrix{$siz...}(UnitLowerTriangular(A)) ), UpperTriangular(A), SVector(ntuple(n->n, max($siz...))))
                    end)

    Wfact_func   = build_function(Wfact  , vs, ps, (:gam,:t), ODEToExpr(sys);constructor=constructor)
    Wfact_t_func = build_function(Wfact_t, vs, ps, (:gam,:t), ODEToExpr(sys);constructor=constructor)

    return (Wfact_func, Wfact_t_func)
end

"""
$(SIGNATURES)

Create an `ODEFunction` from the [`ODESystem`](@ref). The arguments `dvs` and `ps`
are used to set the order of the dependent variable and parameter vectors,
respectively.
"""
function DiffEqBase.ODEFunction{iip}(sys::ODESystem, dvs, ps,
                                     safe = Val{true};
                                     version = nothing,
                                     jac = false, Wfact = false) where {iip}
    _f = eval(generate_function(sys, dvs, ps))
    out_f_safe(u,p,t) = ModelingToolkit.fast_invokelatest(_f,typeof(u),u,p,t)
    out_f_safe(du,u,p,t) = ModelingToolkit.fast_invokelatest(_f,Nothing,du,u,p,t)
    out_f(u,p,t) = _f(u,p,t)
    out_f(du,u,p,t) = _f(du,u,p,t)

    if jac
        _jac = eval(generate_jacobian(sys, dvs, ps))
        jac_f_safe(u,p,t) = ModelingToolkit.fast_invokelatest(_jac,Matrix{eltype(u)},u,p,t)
        jac_f_safe(J,u,p,t) = ModelingToolkit.fast_invokelatest(_jac,Nothing,J,u,p,t)
        jac_f(u,p,t) = _jac(u,p,t)
        jac_f(J,u,p,t) = _jac(J,u,p,t)
    else
        jac_f_safe = nothing
        jac_f = nothing
    end

    if Wfact
        _Wfact,_Wfact_t = eval.(generate_factorized_W(sys, dvs, ps))
        Wfact_f_safe(u,p,gam,t) = ModelingToolkit.fast_invokelatest(_Wfact,Matrix{eltype(u)},u,p,gam,t)
        Wfact_f_safe(J,u,p,gam,t) = ModelingToolkit.fast_invokelatest(_Wfact,Nothing,J,u,p,gam,t)
        Wfact_f_t_safe(u,p,gam,t) = ModelingToolkit.fast_invokelatest(_Wfact_t,Matrix{eltype(u)},u,p,gam,t)
        Wfact_f_t_safe(J,u,p,gam,t) = ModelingToolkit.fast_invokelatest(_Wfact_t,Nothing,J,u,p,gam,t)
        Wfact_f(u,p,gam,t) = _Wfact(u,p,gam,t)
        Wfact_f(J,u,p,gam,t) = _Wfact(J,u,p,gam,t)
        Wfact_f_t(u,p,gam,t) = _Wfact_t(u,p,gam,t)
        Wfact_f_t(J,u,p,gam,t) = _Wfact_t(J,u,p,gam,t)
    else
        Wfact_f_safe = nothing
        Wfact_f_t_safe = nothing
        Wfact_f = nothing
        Wfact_f_t = nothing
    end

    if safe === Val{true}
        ODEFunction{iip}(out_f_safe,jac=jac_f_safe,
                          Wfact = Wfact_f_safe,
                          Wfact_t = Wfact_f_t_safe)
    else
        ODEFunction{iip}(out_f,jac=jac_f,
                          Wfact = Wfact_f,
                          Wfact_t = Wfact_f_t)
    end
end

function DiffEqBase.ODEFunction(sys::ODESystem, args...; kwargs...)
    ODEFunction{true}(sys, args...; kwargs...)
end

"""
$(SIGNATURES)

Generate `ODESystem`, dependent variables, and parameters from an `ODEProblem`.
"""
function modelingtoolkitize(prob::DiffEqBase.ODEProblem)
    @parameters t
    vars = [Variable(:x, i)(t) for i in eachindex(prob.u0)]
    params = [Variable(:α,i; known = true)() for i in eachindex(prob.p)]
    @derivatives D'~t

    rhs = [D(var) for var in vars]

    if DiffEqBase.isinplace(prob)
        lhs = similar(vars, Any)
        prob.f(lhs, vars, params, t)
    else
        lhs = prob.f(vars, params, t)
    end

    eqs = vcat([rhs[i] ~ lhs[i] for i in eachindex(prob.u0)]...)
    de = ODESystem(eqs)

    de, vars, params
end
