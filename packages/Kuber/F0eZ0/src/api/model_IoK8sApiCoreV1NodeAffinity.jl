# This file was generated by the Julia Swagger Code Generator
# Do not modify this file directly. Modify the swagger specification instead.



mutable struct IoK8sApiCoreV1NodeAffinity <: SwaggerModel
    preferredDuringSchedulingIgnoredDuringExecution::Any # spec type: Union{ Nothing, Vector{IoK8sApiCoreV1PreferredSchedulingTerm} } # spec name: preferredDuringSchedulingIgnoredDuringExecution
    requiredDuringSchedulingIgnoredDuringExecution::Any # spec type: Union{ Nothing, IoK8sApiCoreV1NodeSelector } # spec name: requiredDuringSchedulingIgnoredDuringExecution

    function IoK8sApiCoreV1NodeAffinity(;preferredDuringSchedulingIgnoredDuringExecution=nothing, requiredDuringSchedulingIgnoredDuringExecution=nothing)
        o = new()
        validate_property(IoK8sApiCoreV1NodeAffinity, Symbol("preferredDuringSchedulingIgnoredDuringExecution"), preferredDuringSchedulingIgnoredDuringExecution)
        setfield!(o, Symbol("preferredDuringSchedulingIgnoredDuringExecution"), preferredDuringSchedulingIgnoredDuringExecution)
        validate_property(IoK8sApiCoreV1NodeAffinity, Symbol("requiredDuringSchedulingIgnoredDuringExecution"), requiredDuringSchedulingIgnoredDuringExecution)
        setfield!(o, Symbol("requiredDuringSchedulingIgnoredDuringExecution"), requiredDuringSchedulingIgnoredDuringExecution)
        o
    end
end # type IoK8sApiCoreV1NodeAffinity

const _property_map_IoK8sApiCoreV1NodeAffinity = Dict{Symbol,Symbol}(Symbol("preferredDuringSchedulingIgnoredDuringExecution")=>Symbol("preferredDuringSchedulingIgnoredDuringExecution"), Symbol("requiredDuringSchedulingIgnoredDuringExecution")=>Symbol("requiredDuringSchedulingIgnoredDuringExecution"))
const _property_types_IoK8sApiCoreV1NodeAffinity = Dict{Symbol,String}(Symbol("preferredDuringSchedulingIgnoredDuringExecution")=>"Vector{IoK8sApiCoreV1PreferredSchedulingTerm}", Symbol("requiredDuringSchedulingIgnoredDuringExecution")=>"IoK8sApiCoreV1NodeSelector")
Base.propertynames(::Type{ IoK8sApiCoreV1NodeAffinity }) = collect(keys(_property_map_IoK8sApiCoreV1NodeAffinity))
Swagger.property_type(::Type{ IoK8sApiCoreV1NodeAffinity }, name::Symbol) = Union{Nothing,eval(Meta.parse(_property_types_IoK8sApiCoreV1NodeAffinity[name]))}
Swagger.field_name(::Type{ IoK8sApiCoreV1NodeAffinity }, property_name::Symbol) =  _property_map_IoK8sApiCoreV1NodeAffinity[property_name]

function check_required(o::IoK8sApiCoreV1NodeAffinity)
    true
end

function validate_property(::Type{ IoK8sApiCoreV1NodeAffinity }, name::Symbol, val)
end
