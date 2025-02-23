#==========================================================================================#

# ONE SAMPLE: INTERFACE

function hausman_1s(obj₁::ParM2S, obj₂::ParM2S)
    return hausman_1s(obj₁, obj₂, intersect(coefnames(obj₁), coefnames(obj₂)))
end

function hausman_1s(obj₁::ParM2S, obj₂::ParM2S, name::String )

    return hausman_1s(obj₁, obj₂, [name])
end

function hausman_1s(obj₁::ParM2S, obj₂::ParM2S,names::Vector{String})

    i₁    = indexin(names, coefnames(obj₁))
    i₂    = indexin(names, coefnames(obj₂))
    w₁    = getweights(obj₁)
    w₂    = getweights(obj₂)
    corr₁ = getcorr(obj₁)
    corr₂ = getcorr(obj₂)

    (iszero(i₁) | iszero(i₂)) && throw("missing coefficients in at least one model")
    isequal(corr₁, corr₂) || throw("different correlation structures")
    isequal(getweights(obj₁), getweights(obj₂)) || throw("different weighting schemes")

    output       = ParEstimate()
    output.names = copy(names)

    _hausman_1s!(output, obj₁, i₁, obj₂, i₂, w₁, corr₁)

    return output
end

# ONE SAMPLE: ESTIMATION

function _hausman_1s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        obj₂::ParM2S,
        i₂::Vector{Int},
        w::UnitWeights,
        corr::Heteroscedastic
    )

    Ψ₁  = influence(obj₁, w)
    ψ₁  = view(Ψ₁, :, i₁)
    Ψ₂  = influence(obj₂, w)
    ψ₂  = view(Ψ₂, :, i₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_1s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        obj₂::ParM2S,
        i₂::Vector{Int},
        w::FrequencyWeights,
        corr::Heteroscedastic
    )

    Ψ₁  = influence(obj₁, w)
    ψ₁  = view(Ψ₁, :, i₁)
    Ψ₂  = influence(obj₂, w)
    ψ₂  = view(Ψ₂, :, i₂) ; lmul!(Diagonal(w), ψ₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_1s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        obj₂::ParM2S,
        i₂::Vector{Int},
        w::AbstractWeights,
        corr::Heteroscedastic
    )

    Ψ₁  = influence(obj₁, w)
    ψ₁  = view(Ψ₁, :, i₁) ; lmul!(Diagonal(w), ψ₁)
    Ψ₂  = influence(obj₂, w)
    ψ₂  = view(Ψ₂, :, i₂) ; lmul!(Diagonal(w), ψ₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_1s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        obj₂::ParM2S,
        i₂::Vector{Int},
        w::UnitWeights,
        corr::Clustered
    )

    Ψ₁  = influence(obj₁, w)
    ψ₁  = corr.mat * view(Ψ₁, :, i₁)
    Ψ₂  = influence(obj₂, w)
    ψ₂  = corr.mat * view(Ψ₂, :, i₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_1s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        obj₂::ParM2S,
        i₂::Vector{Int},
        w::AbstractWeights,
        corr::Clustered
    )

    Ψ₁  = influence(obj₁, w)
    ψ₁  = corr.mat * view(Ψ₁, :, i₁) ; lmul!(Diagonal(w), ψ₁)
    Ψ₂  = influence(obj₂, w)
    ψ₂  = corr.mat * view(Ψ₂, :, i₂) ; lmul!(Diagonal(w), ψ₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_1s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        obj₂::ParM2S,
        i₂::Vector{Int},
        w::UnitWeights,
        corr::CrossCorrelated
    )

    Ψ₁  = influence(obj₁, w)
    ψ₁  = view(Ψ₁, :, i₁)
    Ψ₂  = influence(obj₂, w)
    ψ₂  = view(Ψ₂, :, i₂)
    V₁₂ = ψ₁' * corr.mat * ψ₂

    adjfactor!(V₁₂, obj₁, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_1s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        obj₂::ParM2S,
        i₂::Vector{Int},
        w::AbstractWeights,
        corr::CrossCorrelated
    )

    Ψ₁  = influence(obj₁, w)
    ψ₁  = view(Ψ₁, :, i₁) ; lmul!(Diagonal(w), ψ₁)
    Ψ₂  = influence(obj₂, w)
    ψ₂  = view(Ψ₂, :, i₂) ; lmul!(Diagonal(w), ψ₂)
    V₁₂ = ψ₁' * corr.mat * ψ₂

    adjfactor!(V₁₂, obj₁, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

#==========================================================================================#

# TWO INDEPENDENT SAMPLES

function hausman_2s(obj₁::ParM2S, obj₂::ParM2S)
    return hausman_2s(obj₁, obj₂, intersect(coefnames(obj₁), coefnames(obj₂)))
end

function hausman_2s(obj₁::ParM2S, obj₂::ParM2S, name::String)
    return hausman_2s(obj₁, obj₂, [name])
end

function hausman_2s(obj₁::ParM2S, obj₂::ParM2S, names::Vector{String})

    i₁ = indexin(names, coefnames(obj₁))
    i₂ = indexin(names, coefnames(obj₂))

    (iszero(i₁) | iszero(i₂)) && throw("missing coefficients in at least one model")

    output       = ParEstimate()
    output.names = copy(names)
    output.β     = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V     = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂)

    return output
end

#==========================================================================================#

# TWO DEPENDENT SAMPLES: INTERFACE

function hausman_2s(obj₁::ParM2S, obj₂::ParM2S, corr::CorrStructure)
    return hausman_2s(obj₁, obj₂, corr, intersect(coefnames(obj₁), coefnames(obj₂)))
end

function hausman_2s(obj₁::ParM2S, obj₂::ParM2S, corr::CorrStructure, name::String)
    return hausman_2s(obj₁, obj₂, corr, [name])
end

function hausman_2s(obj₁::ParM2S, obj₂::ParM2S, corr::CorrStructure, names::Vector{String})

    i₁ = indexin(names, coefnames(obj₁))
    i₂ = indexin(names, coefnames(obj₂))
    w₁ = getweights(obj₁)
    w₂ = getweights(obj₂)

    (iszero(i₁) | iszero(i₂)) && throw("missing coefficients in at least one model")

    if !(typeof(corr) == typeof(getcorr(obj₁)) == typeof(getcorr(obj₂)))
        throw("incompatible correlation structures")
    end

    output       = ParEstimate()
    output.names = copy(names)

    _hausman_2s!(output, obj₁, i₁, w₁, obj₂, i₂, w₂, corr)

    return output
end

# TWO DEPENDENT SAMPLES: ESTIMATION

function _hausman_2s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        w₁::UnitWeights,
        obj₂::ParM2S,
        i₂::Vector{Int},
        w₂::UnitWeights,
        corr::Heteroscedastic
    )

    nonmissing₁ = getnonmissing(obj₁)
    nonmissing₂ = getnonmissing(obj₂)
    touse       = nonmissing₁ .* nonmissing₂
    touse₁      = touse[nonmissing₁]
    touse₂      = touse[nonmissing₂]

    Ψ₁  = influence(obj₁, w₁)
    ψ₁  = view(Ψ₁, touse₁, i₁)
    Ψ₂  = influence(obj₂, w₂)
    ψ₂  = view(Ψ₂, touse₂, i₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, obj₂, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_2s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        w₁::AbstractWeights,
        obj₂::ParM2S,
        i₂::Vector{Int},
        w₂::AbstractWeights,
        corr::Heteroscedastic
    )

    nonmissing₁ = getnonmissing(obj₁)
    nonmissing₂ = getnonmissing(obj₂)
    touse       = nonmissing₁ .* nonmissing₂
    touse₁      = touse[nonmissing₁]
    touse₂      = touse[nonmissing₂]

    Ψ₁  = influence(obj₁, w₁)
    ψ₁  = view(Ψ₁, touse₁, i₁) ; lmul!(Diagonal(w₁), ψ₁)
    Ψ₂  = influence(obj₂, w₂)
    ψ₂  = view(Ψ₂, touse₂, i₂) ; lmul!(Diagonal(w₂), ψ₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, obj₂, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_2s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        w₁::UnitWeights,
        obj₂::ParM2S,
        i₂::Vector{Int},
        w₂::UnitWeights,
        corr::Clustered
    )

    nonmissing₁ = getnonmissing(obj₁)
    nonmissing₂ = getnonmissing(obj₂)

    Ψ₁  = influence(obj₁, w₁)
    ψ₁  = view(corr.mat, :, nonmissing₁) * view(Ψ₁, :, i₁)
    Ψ₂  = influence(obj₂, w₂)
    ψ₂  = view(corr.mat, :, nonmissing₂) * view(Ψ₂, :, i₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, obj₂, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_2s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        w₁::AbstractWeights,
        obj₂::ParM2S,
        i₂::Vector{Int},
        w₂::AbstractWeights,
        corr::Clustered
    )

    nonmissing₁ = getnonmissing(obj₁)
    nonmissing₂ = getnonmissing(obj₂)

    Ψ₁  = influence(obj₁, w₁)
    ψ₁  = view(corr.mat, :, nonmissing₁) * view(Ψ₁, :, i₁) ; lmul!(Diagonal(w₁), ψ₁)
    Ψ₂  = influence(obj₂, w₂)
    ψ₂  = view(corr.mat, :, nonmissing₂) * view(Ψ₂, :, i₂) ; lmul!(Diagonal(w₂), ψ₂)
    V₁₂ = ψ₁' * ψ₂

    adjfactor!(V₁₂, obj₁, obj₂, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_2s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        w₁::UnitWeights,
        obj₂::ParM2S,
        i₂::Vector{Int},
        w₂::UnitWeights,
        corr::CorrStructure
    )

    nonmissing₁ = getnonmissing(obj₁)
    nonmissing₂ = getnonmissing(obj₂)

    Ψ₁  = influence(obj₁, w₁)
    ψ₁  = view(Ψ₁, :, i₁)
    Ψ₂  = influence(obj₂, w₂)
    ψ₂  = view(Ψ₂, :, i₂)
    V₁₂ = ψ₁' * view(corr.mat, nonmissing₁, nonmissing₂) * ψ₂

    adjfactor!(V₁₂, obj₁, obj₂, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end

function _hausman_2s!(
        output::ParEstimate,
        obj₁::ParM2S,
        i₁::Vector{Int},
        w₁::AbstractWeights,
        obj₂::ParM2S,
        i₂::Vector{Int},
        w₂::AbstractWeights,
        corr::CorrStructure
    )

    nonmissing₁ = getnonmissing(obj₁)
    nonmissing₂ = getnonmissing(obj₂)

    Ψ₁  = influence(obj₁, w₁)
    ψ₁  = view(Ψ₁, :, i₁) ; lmul!(Diagonal(w₁), ψ₁)
    Ψ₂  = influence(obj₂, w₂)
    ψ₂  = view(Ψ₂, :, i₂) ; lmul!(Diagonal(w₂), ψ₂)
    V₁₂ = ψ₁' * view(corr.mat, nonmissing₁, nonmissing₂) * ψ₂

    adjfactor!(V₁₂, obj₁, obj₂, corr)

    output.β = view(coef(obj₁), i₁) - view(coef(obj₂), i₂)
    output.V = view(vcov(obj₁), i₁, i₁) + view(vcov(obj₂), i₂, i₂) - (V₁₂' + V₁₂)
end
