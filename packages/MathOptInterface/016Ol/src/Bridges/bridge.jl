"""
    AbstractBridge

Represents a bridged constraint or variable in a
[`MathOptInterface.Bridges.AbstractBridgeOptimizer`](@ref). It contains the
indices of the variables and constraints that it has created in the model. These
can be obtained using [`MathOptInterface.NumberOfVariables`](@ref),
[`MathOptInterface.ListOfVariableIndices`](@ref),
[`MathOptInterface.NumberOfConstraints`](@ref) and
[`MathOptInterface.ListOfConstraintIndices`](@ref) using
[`MathOptInterface.get`](@ref) with the bridge in place of the
[`MathOptInterface.ModelLike`](@ref). Attributes of the bridged model such as
[`MathOptInterface.ConstraintDual`](@ref) and
[`MathOptInterface.ConstraintPrimal`](@ref), can be obtained using
[`MathOptInterface.get`](@ref) with the bridge in place of the constraint index.
These calls are used by the
[`MathOptInterface.Bridges.AbstractBridgeOptimizer`](@ref) to communicate with
the bridge so they should be implemented by the bridge.
"""
abstract type AbstractBridge end

"""
    MOI.get(b::AbstractBridge, ::MOI.NumberOfConstraints{F, S}) where {F, S}

The number of constraints of the type `F`-in-`S` created by the bridge `b` in the model.
"""
MOI.get(::AbstractBridge, ::MOI.NumberOfConstraints) = 0

"""
    MOI.get(b::AbstractBridge, ::MOI.ListOfConstraintIndices{F, S}) where {F, S}

A `Vector{ConstraintIndex{F,S}}` with indices of all constraints of
type `F`-in`S` created by the bride `b` in the model (i.e., of length equal to
the value of `NumberOfConstraints{F,S}()`).
"""
function MOI.get(::AbstractBridge,
                 ::MOI.ListOfConstraintIndices{F, S}) where {F, S}
    return MOI.ConstraintIndex{F, S}[]
end

"""
    MOI.supports(model::MOI.ModelLike, attr::MOI.AbstractConstraintAttribute,
                 BT::Type{<:AbstractBridge})

Return a `Bool` indicating whether `BT` supports setting `attr` to `model`.
"""
function MOI.supports(::MOI.ModelLike, ::MOI.AbstractConstraintAttribute,
                      ::Type{<:AbstractBridge})
    return false
end

"""
    function MOI.get(model::MOI.ModelLike, attr::MOI.AbstractConstraintAttribute,
                     bridge::AbstractBridge)

Return the value of the attribute `attr` of the model `model` for the
constraint bridged by `bridge`.
"""
function MOI.get(::MOI.ModelLike, attr::MOI.AbstractConstraintAttribute,
                 bridge::AbstractBridge)
    throw(ArgumentError("Bridge of type `$(typeof(bridge))` does not support accessing the attribute `$attr`."))
end

"""
    added_constrained_variable_types(BT::Type{<:Variable.AbstractBridge})::Bool

Return a list of the types of constrained variables that bridges of concrete
type `BT` add. This is used by the [`LazyBridgeOptimizer`](@ref).
"""
function added_constrained_variable_types end

"""
    added_constraint_types(BT::Type{<:Constraint.AbstractBridge})::Bool

Return a list of the types of constraints that bridges of concrete type `BT`
add. This is used by the [`LazyBridgeOptimizer`](@ref).
"""
function added_constraint_types end
