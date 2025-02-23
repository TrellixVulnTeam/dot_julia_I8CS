include("validate_input.jl")


"""
    ccm_with_summary(driver,
            response,
            timeseries_lengths;
            average_measure::Symbol = :median,
            uncertainty_measure::Symbol = :quantile,
            quantiles = [0.327, 0.673],
            kwargs...)

## Algorithm
Compute the cross mapping between a `driver` series and a `response` series over
different `timeseries_lengths` and return summary statistics of the results.

## Arguments
- **`driver`**: The data series representing the putative driver process.
- **`response`**: The data series representing the putative response process.
- **`timeseries_lengths`**: Time series length(s) for which to compute the
    cross mapping(s).

## Summary keyword arguments
- **`average_measure`**: Either `:median` or `:mean`. Default is `:median`.
- **`uncertainty_measure`**: Either `:quantile` or `:std`. Default is `:quantile`.
- **`quantiles`**: Compute uncertainty over quantile(s) if `uncertainty_measure`
    is `:quantile`. Default is `[0.327, 0.673]`, roughly corresponding to 1s for
    normally distributed data.

## Keyword arguments to `crossmap`
- **`dim`**: The dimension of the state space reconstruction (delay embedding)
    constructed from the `response` series. Default is `dim = 3`.
- **`τ`**: The embedding lag for the delay embedding constructed from `response`.
    Default is `τ = 1`.
- **`ν`**: The prediction lag to use when predicting scalar values of `driver`
    fromthe delay embedding of `response`.
    `ν > 0` are forward lags (causal; `driver`'s past influences `response`'s future),
    and `ν < 0` are backwards lags (non-causal; `driver`'s' future influences
    `response`'s past). Adjust the prediction lag if you
    want to performed lagged ccm
    [(Ye et al., 2015)](https://www.nature.com/articles/srep14750).
    Default is `ν = 0`, as in
    [Sugihara et al. (2012)](http://science.sciencemag.org/content/early/2012/09/19/science.1227079).
    *Note: The sign of the lag `ν` is organized to conform with the conventions in
    [TransferEntropy.jl](), and is opposite to the convention used in the
    [`rEDM`](https://cran.r-project.org/web/packages/rEDM/index.html) package
    ([Ye et al., 2016](https://cran.r-project.org/web/packages/rEDM/index.html)).*
- **`libsize`**: Among how many delay embedding points should we sample time indices
    and look for nearest neighbours at each cross mapping realization (of which there
    are `n_reps`)?
- **`n_reps`**: The number of times we draw a library of `libsize` points from the
    delay embedding of `response` and try to predict `driver` values. Equivalently,
    how many times do we cross map for this value of `libsize`?
    Default is `n_reps = 100`.
- **`replace`**: Sample delay embedding points with replacement? Default is `replace = true`.
- **`exclusion_radius`**: How many temporal neighbors of the delay embedding
    point `response_embedding(t)` to exclude when searching for neighbors to
    determine weights for predicting the scalar point `driver(t + ν)`.
    Default is `exclusion_radius = 0`.
- **`which_is_surr`**: Which data series should be replaced by a surrogate
    realization of the type given by `surr_type`? Must be one of the
    following: `:response`, `:driver`, `:none`, `:both`.
    Default is `:none`.
- **`surr_func`**: A valid surrogate function from TimeseriesSurrogates.jl.
- **`tree_type`**: The type of tree to build when looking for nearest neighbors.
    Must be a tree type from NearestNeighbors.jl. For now, this is either
    `BruteTree`, `KDTree` or `BallTree`.
- **`distance_metric`**: An instance of a `Metric` from Distances.jl. `BallTree` and `BruteTree` work with any `Metric`.
    `KDTree` only works with the axis aligned metrics `Euclidean`, `Chebyshev`,
    `Minkowski` and `Cityblock`. Default is `metric = Euclidean()` *(note the instantiation of the metric)*.
- **`correspondence_measure`**: The function that computes the correspondence
    between actual values of `driver` and predicted values. Can be any
    function returning a similarity measure between two vectors of values.
    Default is `correspondence_measure = StatsBase.cor`, which returns values on ``[-1, 1]``.
    In this case, any negative values are usually filtered out (interpreted as zero coupling) and
    a value of ``1`` means perfect prediction.
    [Sugihara et al. (2012)](http://science.sciencemag.org/content/early/2012/09/19/science.1227079)
    also proposes to use the root mean square deviation, for which a value of ``0`` would
    be perfect prediction.

## References
Sugihara, George, et al. "Detecting causality in complex ecosystems."
Science (2012): 1227079.
[http://science.sciencemag.org/content/early/2012/09/19/science.1227079](http://science.sciencemag.org/content/early/2012/09/19/science.1227079)

Ye, Hao, et al. "Distinguishing time-delayed causal interactions using convergent cross mapping." Scientific Reports 5 (2015): 14750.
[https://www.nature.com/articles/srep14750](https://www.nature.com/articles/srep14750)

Ye, H., et al. "rEDM: Applications of empirical dynamic modeling from time series." R Package Version 0.4 7 (2016).
[https://cran.r-project.org/web/packages/rEDM/index.html](https://cran.r-project.org/web/packages/rEDM/index.html)
"""
function ccm_with_summary(driver,
            response,
            timeseries_lengths;
            average_measure::Symbol = :median,
            uncertainty_measure::Symbol = :quantile,
            quantiles = [0.327, 0.673],
            kwargs...)

    if average_measure ∈ [:median, :mean]
            average = zeros(Float64, length(timeseries_lengths))
        end

        if uncertainty_measure == :quantile
            uncertainties = zeros(Float64, length(timeseries_lengths), length(quantiles))
        elseif uncertainty_measure == :std
            uncertainties = zeros(Float64, length(timeseries_lengths))
        end

        for (i, ts_len) in enumerate(timeseries_lengths)
            correlations = crossmap(driver[1:ts_len], response[1:ts_len]; kwargs...)

            if average_measure == :mean
                average[i] = mean(correlations)
            elseif average_measure == :median
                average[i] = median(correlations)
            end

            if uncertainty_measure == :quantile
                for (j, quant) in enumerate(quantiles)
                    uncertainties[i, j] = quantile(correlations, quant)
                end
            elseif uncertainty_measure == :std
                uncertainties[i] = std(correlations)
            end
        end

        if average_measure == :none
            return uncertainties
        elseif uncertainty_measure == :none
            return average
        else
            return average, uncertainties
        end
end


"""
    ccm(driver,
            response,
            timeseries_lengths;
            kwargs...) -> Vector{Vector{Float64}}

## Algorithm
Compute the cross mapping between a `driver` series and a `response` series over
different `timeseries_lengths`.

## Arguments
- **`driver`**: The data series representing the putative driver process.
- **`response`**: The data series representing the putative response process.
- **`timeseries_lengths`**: Time series length(s) for which to compute the
    cross mapping(s).

## Keyword arguments to `crossmap`
- **`dim`**: The dimension of the state space reconstruction (delay embedding)
    constructed from the `response` series. Default is `dim = 3`.
- **`τ`**: The embedding lag for the delay embedding constructed from `response`.
    Default is `τ = 1`.
- **`ν`**: The prediction lag to use when predicting scalar values of `driver`
    fromthe delay embedding of `response`.
    `ν > 0` are forward lags (causal; `driver`'s past influences `response`'s future),
    and `ν < 0` are backwards lags (non-causal; `driver`'s' future influences
    `response`'s past). Adjust the prediction lag if you
    want to performed lagged ccm
    [(Ye et al., 2015)](https://www.nature.com/articles/srep14750).
    Default is `ν = 0`, as in
    [Sugihara et al. (2012)](http://science.sciencemag.org/content/early/2012/09/19/science.1227079).
    *Note: The sign of the lag `ν` is organized to conform with the conventions in
    [TransferEntropy.jl](), and is opposite to the convention used in the
    [`rEDM`](https://cran.r-project.org/web/packages/rEDM/index.html) package
    ([Ye et al., 2016](https://cran.r-project.org/web/packages/rEDM/index.html)).*
- **`libsize`**: Among how many delay embedding points should we sample time indices
    and look for nearest neighbours at each cross mapping realization (of which there
    are `n_reps`)?
- **`n_reps`**: The number of times we draw a library of `libsize` points from the
    delay embedding of `response` and try to predict `driver` values. Equivalently,
    how many times do we cross map for this value of `libsize`?
    Default is `n_reps = 100`.
- **`replace`**: Sample delay embedding points with replacement? Default is `replace = true`.
- **`exclusion_radius`**: How many temporal neighbors of the delay embedding
    point `response_embedding(t)` to exclude when searching for neighbors to
    determine weights for predicting the scalar point `driver(t + ν)`.
    Default is `exclusion_radius = 0`.
- **`which_is_surr`**: Which data series should be replaced by a surrogate
    realization of the type given by `surr_type`? Must be one of the
    following: `:response`, `:driver`, `:none`, `:both`.
    Default is `:none`.
- **`surr_func`**: A valid surrogate function from TimeseriesSurrogates.jl.
- **`tree_type`**: The type of tree to build when looking for nearest neighbors.
    Must be a tree type from NearestNeighbors.jl. For now, this is either
    `BruteTree`, `KDTree` or `BallTree`.
- **`distance_metric`**: An instance of a `Metric` from Distances.jl. `BallTree` and `BruteTree` work with any `Metric`.
    `KDTree` only works with the axis aligned metrics `Euclidean`, `Chebyshev`,
    `Minkowski` and `Cityblock`. Default is `metric = Euclidean()` *(note the instantiation of the metric)*.
- **`correspondence_measure`**: The function that computes the correspondence
    between actual values of `driver` and predicted values. Can be any
    function returning a similarity measure between two vectors of values.
    Default is `correspondence_measure = StatsBase.cor`, which returns values on ``[-1, 1]``.
    In this case, any negative values are usually filtered out (interpreted as zero coupling) and
    a value of ``1`` means perfect prediction.
    [Sugihara et al. (2012)](http://science.sciencemag.org/content/early/2012/09/19/science.1227079)
    also proposes to use the root mean square deviation, for which a value of ``0`` would
    be perfect prediction.

## References
Sugihara, George, et al. "Detecting causality in complex ecosystems."
Science (2012): 1227079.
[http://science.sciencemag.org/content/early/2012/09/19/science.1227079](http://science.sciencemag.org/content/early/2012/09/19/science.1227079)

Ye, Hao, et al. "Distinguishing time-delayed causal interactions using convergent cross mapping." Scientific Reports 5 (2015): 14750.
[https://www.nature.com/articles/srep14750](https://www.nature.com/articles/srep14750)

Ye, H., et al. "rEDM: Applications of empirical dynamic modeling from time series." R Package Version 0.4 7 (2016).
[https://cran.r-project.org/web/packages/rEDM/index.html](https://cran.r-project.org/web/packages/rEDM/index.html)
"""
function ccm(driver,
            response,
            timeseries_lengths;
            kwargs...)

    [crossmap(driver[1:ts_len], response[1:ts_len]; kwargs...)
            for ts_len in timeseries_lengths]
end


"""
    convergentcrossmap(driver,
            response,
            timeseries_lengths;
            summarise::Bool = true,
            average_measure::Symbol = :median,
            uncertainty_measure::Symbol = :quantile,
            quantiles = [0.327, 0.673],
            kwargs...)

## Algorithm
Compute the cross mapping between a `driver` series and a `response` series over
different `timeseries_lengths`. If `summarise = true`, then call `ccm_with_summary`.
If `summarise = false`, then call `ccm` (returns raw crossmap skills).

## Arguments
- **`driver`**: The data series representing the putative driver process.
- **`response`**: The data series representing the putative response process.
- **`timeseries_lengths`**: Time series length(s) for which to compute the
    cross mapping(s).

## Summary keyword arguments
- **`summarise`**: Should cross map skills be summarised for each time series length?
    Default is `summarise = true`.
- **`average_measure`**: Either `:median` or `:mean`. Default is `:median`.
- **`uncertainty_measure`**: Either `:quantile` or `:std`. Default is `:quantile`.
- **`quantiles`**: Compute uncertainty over quantile(s) if `uncertainty_measure`
    is `:quantile`. Default is `[0.327, 0.673]`, roughly corresponding to 1s for
    normally distributed data.

## Keyword arguments to `crossmap`
- **`dim`**: The dimension of the state space reconstruction (delay embedding)
    constructed from the `response` series. Default is `dim = 3`.
- **`τ`**: The embedding lag for the delay embedding constructed from `response`.
    Default is `τ = 1`.
- **`ν`**: The prediction lag to use when predicting scalar values of `driver`
    fromthe delay embedding of `response`.
    `ν > 0` are forward lags (causal; `driver`'s past influences `response`'s future),
    and `ν < 0` are backwards lags (non-causal; `driver`'s' future influences
    `response`'s past). Adjust the prediction lag if you
    want to performed lagged ccm
    [(Ye et al., 2015)](https://www.nature.com/articles/srep14750).
    Default is `ν = 0`, as in
    [Sugihara et al. (2012)](http://science.sciencemag.org/content/early/2012/09/19/science.1227079).
    *Note: The sign of the lag `ν` is organized to conform with the conventions in
    [TransferEntropy.jl](), and is opposite to the convention used in the
    [`rEDM`](https://cran.r-project.org/web/packages/rEDM/index.html) package
    ([Ye et al., 2016](https://cran.r-project.org/web/packages/rEDM/index.html)).*
- **`libsize`**: Among how many delay embedding points should we sample time indices
    and look for nearest neighbours at each cross mapping realization (of which there
    are `n_reps`)?
- **`n_reps`**: The number of times we draw a library of `libsize` points from the
    delay embedding of `response` and try to predict `driver` values. Equivalently,
    how many times do we cross map for this value of `libsize`?
    Default is `n_reps = 100`.
- **`replace`**: Sample delay embedding points with replacement? Default is `replace = true`.
- **`exclusion_radius`**: How many temporal neighbors of the delay embedding
    point `response_embedding(t)` to exclude when searching for neighbors to
    determine weights for predicting the scalar point `driver(t + ν)`.
    Default is `exclusion_radius = 0`.
- **`which_is_surr`**: Which data series should be replaced by a surrogate
    realization of the type given by `surr_type`? Must be one of the
    following: `:response`, `:driver`, `:none`, `:both`.
    Default is `:none`.
- **`surr_func`**: A valid surrogate function from TimeseriesSurrogates.jl.
- **`tree_type`**: The type of tree to build when looking for nearest neighbors.
    Must be a tree type from NearestNeighbors.jl. For now, this is either
    `BruteTree`, `KDTree` or `BallTree`.
- **`distance_metric`**: An instance of a `Metric` from Distances.jl. `BallTree` and `BruteTree` work with any `Metric`.
    `KDTree` only works with the axis aligned metrics `Euclidean`, `Chebyshev`,
    `Minkowski` and `Cityblock`. Default is `metric = Euclidean()` *(note the instantiation of the metric)*.
- **`correspondence_measure`**: The function that computes the correspondence
    between actual values of `driver` and predicted values. Can be any
    function returning a similarity measure between two vectors of values.
    Default is `correspondence_measure = StatsBase.cor`, which returns values on ``[-1, 1]``.
    In this case, any negative values are usually filtered out (interpreted as zero coupling) and
    a value of ``1`` means perfect prediction.
    [Sugihara et al. (2012)](http://science.sciencemag.org/content/early/2012/09/19/science.1227079)
    also proposes to use the root mean square deviation, for which a value of ``0`` would
    be perfect prediction.

## References
Sugihara, George, et al. "Detecting causality in complex ecosystems."
Science (2012): 1227079.
[http://science.sciencemag.org/content/early/2012/09/19/science.1227079](http://science.sciencemag.org/content/early/2012/09/19/science.1227079)

Ye, Hao, et al. "Distinguishing time-delayed causal interactions using convergent cross mapping." Scientific Reports 5 (2015): 14750.
[https://www.nature.com/articles/srep14750](https://www.nature.com/articles/srep14750)

Ye, H., et al. "rEDM: Applications of empirical dynamic modeling from time series." R Package Version 0.4 7 (2016).
[https://cran.r-project.org/web/packages/rEDM/index.html](https://cran.r-project.org/web/packages/rEDM/index.html)
"""
function convergentcrossmap(driver,
            response,
            timeseries_lengths;
            summarise::Bool = true,
            average_measure::Symbol = :median,
            uncertainty_measure::Symbol = :quantile,
            quantiles = [0.327, 0.673],
            kwargs...)

    validate_average_measure(average_measure)
    validate_uncertainty_measure(uncertainty_measure)
    validate_output_selection(average_measure, uncertainty_measure, summarise)

    if summarise
        ccm_with_summary(driver,
            response,
            timeseries_lengths;
            average_measure = average_measure,
            uncertainty_measure = uncertainty_measure,
            quantiles = quantiles,
            kwargs...)
    else
        ccm(driver,
            response,
            timeseries_lengths;
            kwargs...)
    end

end


export
ccm_with_summary,
ccm,
convergentcrossmap
