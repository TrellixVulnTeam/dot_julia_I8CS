##############################################################################
##
## get weight
## 
##############################################################################

function get_weights(df::AbstractDataFrame, esample::AbstractVector, weights::Symbol) 
    # there are no NA in it. DataVector to Vector
    out = convert(Vector{Float64}, df[esample, weights])
    map!(sqrt, out, out)
    return out
end
get_weights(df::AbstractDataFrame, esample::AbstractVector, ::Nothing) = Ones{Float64}(sum(esample))

##############################################################################
##
## build model
##
##############################################################################

function reftype(sz) 
    sz <= typemax(UInt8)  ? UInt8 :
    sz <= typemax(UInt16) ? UInt16 :
    sz <= typemax(UInt32) ? UInt32 :
    UInt64
end


function ModelFrame2(trms::Terms, d::AbstractDataFrame, esample; contrasts::Dict = Dict())
    df = DataFrame(map(x -> d[x], trms.eterms), Symbol.(trms.eterms))
    df = df[esample, :]
    names!(df, Symbol.(string.(trms.eterms)))
    evaledContrasts = evalcontrasts(df, contrasts)
    ## Check for non-redundant terms, modifying terms in place
    check_non_redundancy!(trms, df)
    ModelFrame(df, trms, esample, evaledContrasts)
end

#  remove observations with negative weights
function isnaorneg(a::Vector{T}) where {T}
    out = BitArray(undef, length(a))
    @simd for i in 1:length(a)
        @inbounds out[i] = !ismissing(a[i]) & (a[i] > zero(T))
    end
    return out
end


function _split(df::AbstractDataFrame, ss::Vector{Symbol})
    catvars, contvars = Symbol[], Symbol[]
    for s in ss
        isa(df[s], CategoricalVector) ? push!(catvars, s) : push!(contvars, s)
    end
    return catvars, contvars
end
##############################################################################
##
## sum of squares
##
##############################################################################

function compute_tss(y::Vector{Float64}, hasintercept::Bool, ::Ones)
    if hasintercept
        tss = zero(Float64)
        m = mean(y)::Float64
        @inbounds @simd  for i in 1:length(y)
            tss += abs2((y[i] - m))
        end
    else
        tss = sum(abs2, y)
    end
    return tss
end

function compute_tss(y::Vector{Float64}, hasintercept::Bool, sqrtw::Vector{Float64})
    if hasintercept
        m = (mean(y) / sum(sqrtw) * length(y))::Float64
        tss = zero(Float64)
        @inbounds @simd  for i in 1:length(y)
         tss += abs2(y[i] - sqrtw[i] * m)
        end
    else
        tss = sum(abs2, y)
    end
    return tss
end

