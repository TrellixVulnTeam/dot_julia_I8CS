__precompile__()
module Rsvg

depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
isfile(depsjl) ? include(depsjl) : error("Rsvg not properly ",
    "installed. Please run\nPkg.build(\"Rsvg\")")

using Cairo, Compat

include("gerror.jl")
include("gio.jl")
include("types.jl")
include("calls.jl")

export RsvgDimensionData, RsvgHandle


function __init__()
	Rsvg.set_default_dpi(72.0) 
end

end # module                                            






