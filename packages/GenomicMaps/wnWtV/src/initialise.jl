"""
    initialise(chr; kwargs...)

Initialise drawing and return a `Dict` containing properties.
"""
function initialise(chr; drawingsize = "A0landscape",
        outfile = "genomap.svg", nbreaks = 30, textangle = -pi/6,
        numberstyle = 'k', defaultcolour = "gray75", arrowwidth = 12,
        genetextsize = 15, colourfunction = x -> x.feature, colourmap = Dict(),
        features = ["CDS", "rRNA", "tRNA"], drawlegend = true,
        rightlimit = 0.95, leftlimit = 0.01, annotate = true,
        extrafunction = (p) -> nothing,
        genetextfunction = x -> get(x, :gene, ""))
    (xmax, ymax) = drawingdimensions(drawingsize)
    drawing = Drawing(xmax, ymax, outfile)
    background("white")
    p = Dict()
    p[:genetextsize] = genetextsize
    p[:chromosome] = chr
    p[:drawing] = drawing
    p[:outfile] = outfile
    p[:interval] = Int(round(length(chr.sequence) / nbreaks, RoundUp))
    p[:textangle] = textangle
    p[:annotate] = annotate
    breaks = 1:p[:interval]:length(chr.sequence)
    left = Point[]
    right = Point[]
    p[:rightlimit] = rightlimit
    p[:leftlimit] = leftlimit
    @inbounds for i in 1:length(breaks)
        push!(left,  Point(p[:leftlimit] * xmax, i * ymax / (length(breaks) + 1)))
        push!(right, Point(p[:rightlimit] * xmax, i * ymax / (length(breaks) + 1)))
    end
    lastpoint = between(left[end], right[end], (length(chr.sequence) - breaks[end]) / (p[:interval] - 1))
    p[:breaks] = breaks
    p[:left] = left
    p[:right] = right
    p[:lastpoint] = lastpoint
    p[:numberstyle] = numberstyle
    p[:offset_y] = ymax / 150
    p[:defaultcolour] = defaultcolour
    p[:arrowwidth] = arrowwidth
    p[:xmax] = xmax
    p[:ymax] = ymax
    p[:drawlegend] = drawlegend
    p[:genetextoffset] = -p[:arrowwidth] - ymax / 20nbreaks
    p[:features] = features
    p[:colourfunction] = colourfunction
    if !isempty(colourmap)
        p[:colourmap] = colourmap
    else
        p[:colourmap] = generatecolours(p)
    end
    ### genetextfunction can be either a function that, given a Gene, returns
    # the text to plot above the gene, or a Symbol showing which property of the
    # gene to plot
    if genetextfunction isa Symbol
        p[:genetextfunction] = g -> getproperty(g, genetextfunction, "")
    else
        p[:genetextfunction] = genetextfunction
    end
    p[:extrafunction] = extrafunction
    return p
end


function generatecolours(p)
    chr = p[:chromosome]
    features = p[:features]
    plottedgenes = @genes(chr, :feature in features)
    categories = unique(vcat(p[:colourfunction].(plottedgenes)...))
    colours = Dict()
    cmap = Colors.distinguishable_colors(length(categories))
    for i in eachindex(categories)
        colours[categories[i]] = cmap[i]
    end
    return colours
end
