using JSON

function get_lines(path::String)
    file_contents = read(open(path), String)
    file_contents = replace(file_contents, "\t" => "    ")
    return split(file_contents, "\n")
end

function add_section(line::SubString{String}, next_line::SubString{String}, data::Dict{String, Any})
    # Determine the title of the section and convert to lowercase.
    section_title = lowercase(strip(line, ['[', ']']))

    # Check if column headings exist for the section.
    headings_exist = occursin(r"^;", next_line)

    if !headings_exist
        # Initialize the section dictionary.
        data["$(section_title)"] = Dict{String, Any}()
    end

    return section_title, headings_exist
end

function get_sections(lines::Array{SubString{String}, 1})
    sections = Dict{String, Any}()
    section = headings = nothing
    headings_exist = false

    for (i, line) in enumerate(lines)
        # Section headings always look like [SECTION_TITLE].
        if occursin(r"^\s*\[(.*)\]", line) # If a section title...
            section, headings_exist = add_section(line, lines[i+1], sections)
        elseif occursin(r"^;", line) # If a section heading....
            # Determine the column headings.
            headings = split(lowercase(strip(line, [';'])))

            # Initialize the section dictionary.
            sections["$section"] = Dict{String, Array}(s => [] for s in headings)
        elseif length(line) == 0 # If the line has no characters...
            continue
        else # Otherwise, this line is data within the section.
            if headings_exist
                data = split(lowercase(strip(line, [';'])))

                for (j, heading) in enumerate(headings)
                    data = split(lowercase(strip(line, [';'])))

                    if j <= length(data)
                        push!(sections["$section"]["$heading"], data[j])
                    else
                        push!(sections["$section"]["$heading"], "")
                    end
                end
            else
                heading = strip(split(line, "  ")[1])
                data = split(lowercase(strip(replace(line, heading => ""), [';'])))
                sections["$section"][lowercase(heading)] = data
            end
        end
    end

    return sections
end

"""
    parse_epanet(path)

Parses an [EPANET](https://www.epa.gov/water-research/epanet) (.inp) file from
the file path `path` and returns a WaterModels data structure (a dictionary of
data). See the [OpenWaterAnalytics
Wiki](https://github.com/OpenWaterAnalytics/EPANET/wiki/Input-File-Format) for
a thorough description of the EPANET format and its components.
"""
function parse_epanet(path::String)
    lines = get_lines(path)
    get_sections(lines)

    section = headings = nothing
    headings_exist = false
    epanet_dict = get_sections(lines)

    # Parse important options first.
    options = parse_options(epanet_dict["options"])

    # Parse relevant data into a more structured format.
    dict = Dict{String, Any}()
    dict["title"] = parse_title(epanet_dict["title"])
    dict["junctions"] = parse_junctions(epanet_dict["junctions"], options)
    dict["pipes"] = parse_pipes(epanet_dict["pipes"], options)
    dict["reservoirs"] = parse_reservoirs(epanet_dict["reservoirs"], options)
    dict["tanks"] = parse_tanks(epanet_dict["tanks"])
    dict["valves"] = parse_valves(epanet_dict["valves"])
    dict["per_unit"] = false
    dict["multinetwork"] = false

    return dict
end

function allequal(x) 
    return all(y->y == x[1], x)
end

function parse_general(dtype::Type, data::Any)
    do_not_parse = dtype == String || dtype == FLOW_DIRECTION || dtype == typeof(data)
    return do_not_parse ? data : parse(dtype, data)
end

function parse_title(data::Dict{String, Any})
    return length(keys(data)) > 0 ? first(keys(data)) : ""
end

function parse_junctions(data::Dict{String, Array}, options::Dict{String, Any})
    # Get the demand units (e.g., LPS, GPM).
    demand_units = options["units"]

    # Initialize scalars to convert data to SI units.
    demand_scalar = nothing
    elev_scalar = nothing

    if demand_units == "lps" # If liters per second...
        # Convert from liters per second to cubic meters per second.
        demand_scalar = 1.0e-3 * options["demand_multiplier"]

        # Retain the original value (in meters).
        elev_scalar = 1.0
    elseif demand_units == "gpm" # If gallons per minute...
        # Convert from gallons per minute to cubic meters per second.
        demand_scalar = 6.30902e-5 * options["demand_multiplier"]

        # Convert elevation from feet to meters.
        elev_scalar = 0.3048
    else
        error("Could not find a valid \"units\" option type.")
    end

    # Convert demand data to SI units.
    data["demand"] = [parse(Float64, demand) for demand in data["demand"]]
    data["demand"] = demand_scalar .* data["demand"]

    # Convert elev data to SI units.
    data["elev"] = [parse(Float64, elev) for elev in data["elev"]]
    data["elev"] = elev_scalar .* data["elev"]

    # Specify the data types for the junction data.
    columns = Dict("demand" => Float64, "elev" => Float64,
                   "id" => String, "pattern" => String)

    # Ensure the arrays describing junction data are all of equal lengths.
    @assert(allequal([length(data[column]) for column in keys(columns)]))

    # Return an array of junction dictionaries with the correct data types.
    arr = [Dict(c => parse_general(v, data[c][i]) for (c, v) in columns) for i = 1:length(data["id"])]

    # Scale the quantities appropriately.
    return Dict{String, Any}(string(data["id"][i]) => arr[i] for i = 1:length(arr))
end

function parse_pipes(data::Dict{String, Array}, options::Dict{String, Any})
    # Get the demand units (e.g., LPS, GPM).
    demand_units = options["units"]

    # Get the headloss type (i.e., Darcy-Weisbach or Hazen-Williams)
    headloss_type = options["headloss"]

    # Initialize scalars to convert data to SI units.
    diameter_scalar = nothing
    length_scalar = nothing
    roughness_scalar = nothing

    if demand_units == "lps" # If liters per second...
        # Convert diameter from millimeters to meters.
        diameter_scalar = 0.001

        # Retain the original value (in meters).
        length_scalar = 1.0

        if headloss_type == "d-w"
            # Convert roughness from millimeters to meters.
            roughness_scalar = 0.001
        elseif headloss_type == "h-w"
            # Retain the original value (unitless).
            roughness_scalar = 1.0
        end
    elseif demand_units == "gpm" # If gallons per minute...
        # Convert diameter from inches to meters.
        diameter_scalar = 0.0254

        # Convert length from feet to meters.
        length_scalar = 0.3048

        if headloss_type == "d-w"
            # Convert roughness from millifeet to meters.
            roughness_scalar = 3.048e-4
        elseif headloss_type == "h-w"
            # Retain the original value (unitless).
            roughness_scalar = 1.0
        end
    else
        error("Could not find a valid \"units\" option type.")
    end

    # Convert diameter data to SI units.
    data["diameter"] = [parse(Float64, diameter) for diameter in data["diameter"]]
    data["diameter"] = diameter_scalar .* data["diameter"]

    # Convert length data to SI units.
    data["length"] = [parse(Float64, length) for length in data["length"]]
    data["length"] = length_scalar .* data["length"]

    # Convert roughness data to SI units.
    data["roughness"] = [parse(Float64, roughness) for roughness in data["roughness"]]
    data["roughness"] = roughness_scalar .* data["roughness"]

    # Specify the data types for the pipe data.
    columns = Dict("diameter" => Float64, "id" => String, "length" => Float64,
                   "minorloss" => Float64, "node1" => String, "node2" => String,
                   "roughness" => Float64, "status" => String,
                   "flow_direction" => FLOW_DIRECTION)

    # Populate the flow direction data.
    data["flow_direction"] = Array{FLOW_DIRECTION}(undef, length(data["id"]))
    fill!(data["flow_direction"], UNKNOWN)

    # Ensure the arrays describing pipe data are all of equal lengths.
    @assert(allequal([length(data[column]) for column in keys(columns)]))

    # Create a dictionary of pipe dictionaries with the correct data types.
    arr = [Dict(c => parse_general(v, data[c][i]) for (c, v) in columns) for i = 1:length(data["id"])]
    return Dict{String, Any}(string(data["id"][i]) => arr[i] for i = 1:length(arr))
end

function parse_reservoirs(data::Dict{String, Array}, options::Dict{String, Any})
    demand_units = options["units"]
    head_scalar = nothing

    if demand_units == "lps" # If liters per second...
        # Retain the original value (in meters).
        head_scalar = 1.0
    elseif demand_units == "gpm" # If gallons per minute...
        # Convert from feet to meters.
        head_scalar = 0.3048
    else
        error("Could not find a valid \"units\" option type.")
    end

    # Convert diameter data to SI units.
    data["head"] = [parse(Float64, head) for head in data["head"]]
    data["head"] = head_scalar .* data["head"]

    # Specify the data types for the reservoir data.
    columns = Dict("head" => Float64, "id" => String, "pattern" => String)

    # Ensure the arrays describing reservoir data are all of equal lengths.
    @assert(allequal([length(data[column]) for column in keys(columns)]))

    # Return an array of reservoir dictionaries with the correct data types.
    arr = [Dict(c => parse_general(v, data[c][i]) for (c, v) in columns) for i = 1:length(data["id"])]
    return Dict{String, Any}(string(data["id"][i]) => arr[i] for i = 1:length(arr))
end

function parse_tanks(data::Dict{String, Array})
    # Specify the data types for the tank data.
    columns = Dict("diameter" => Float64, "elevation" => Float64,
                   "id" => String, "initlevel" => Float64,
                   "maxlevel" => Float64, "minlevel" => Float64,
                   "minvol" => Float64, "volcurve" => String)

    # Ensure the arrays describing tank data are all of equal lengths.
    @assert(allequal([length(data[column]) for column in keys(columns)]))

    # Return an array of tank dictionaries with the correct data types.
    arr = [Dict(c => parse_general(v, data[c][i]) for (c, v) in columns) for i = 1:length(data["id"])]
    return Dict{String, Any}(string(data["id"][i]) => arr[i] for i = 1:length(arr))
end

function parse_valves(data::Dict{String, Array})
    # Specify the data types for the valve data.
    columns = Dict("diameter" => Float64, "id" => String,
                   "minorloss" => Float64, "node1" => String,
                   "node2" => String, "setting" => Float64,
                   "type" => String)

    # Ensure the arrays describing valve data are all of equal lengths.
    @assert(allequal([length(data[column]) for column in keys(columns)]))

    # Return an array of valve dictionaries with the correct data types.
    arr = [Dict(c => parse_general(v, data[c][i]) for (c, v) in columns) for i = 1:length(data["id"])]
    return Dict{String, Any}(string(data["id"][i]) => arr[i] for i = 1:length(arr))
end

function parse_options(data::Dict{String, Any})
    units = data["units"][1]
    headloss = data["headloss"][1]
    demand_multiplier = parse(Float64, data["demand multiplier"][1])
    viscosity = parse(Float64, data["viscosity"][1]) * 1.0e-3
    return Dict{String, Any}("units" => units, "headloss" => headloss,
                             "demand_multiplier" => demand_multiplier,
                             "viscosity" => viscosity)
end
