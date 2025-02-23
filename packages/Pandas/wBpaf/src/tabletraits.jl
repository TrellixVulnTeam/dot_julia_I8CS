using IteratorInterfaceExtensions
using TableTraitsUtils
import DataValues

IteratorInterfaceExtensions.isiterable(x::DataFrame) = true
TableTraits.isiterabletable(x::DataFrame) = true

function TableTraits.getiterator(df::DataFrame)
    col_names_raw = [i for i in Pandas.columns(df)]
    col_names = Symbol.(col_names_raw)

    column_data = [eltype(df[i])==String ? [df[i][j] for j=1:length(df)] : values(df[i]) for i in col_names_raw]

    return create_tableiterator(column_data, col_names)
end

function _construct_pandas_from_iterabletable(source)
    y = create_columns_from_iterabletable(source, errorhandling=:returnvalue)
    y===nothing && return nothing
    columns, column_names = y[1], y[2]
    cols = Dict{Symbol,Any}(i[1]=>i[2] for i in zip(column_names, columns))

    for (k,v) in pairs(cols)
        if eltype(v)<:DataValues.DataValue
            T = eltype(eltype(v))
            if T<:AbstractFloat
                cols[k] = T[get(i, NaN) for i in v]
            elseif T<:Integer
                cols[k] = Float64[DataValues.isna(i) ? NaN : Float64(get(i)) for i in v]
            else
                throw(ArgumentError("Can't create a Pandas.DataFrame from a source that has missing data."))
            end
        end
    end

    return DataFrame(cols)
end
