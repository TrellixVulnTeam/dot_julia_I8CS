# GeoJSON.jl

[![Build Status](https://travis-ci.org/JuliaGeo/GeoJSON.jl.svg)](https://travis-ci.org/JuliaGeo/GeoJSON.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/JuliaGeo/GeoJSON.jl?svg=true&branch=master)](https://ci.appveyor.com/project/JuliaGeo/GeoJSON-jl/branch/master)
[![Coverage Status](https://coveralls.io/repos/JuliaGeo/GeoJSON.jl/badge.svg)](https://coveralls.io/r/JuliaGeo/GeoJSON.jl)

This library is developed independently of, but is heavily influenced in design by the [python-geojson](https://github.com/frewsxcv/python-geojson) package. It contains:

- Functions for encoding and decoding GeoJSON formatted data
- a type hierarchy (according to the [GeoJSON specification](http://geojson.org/geojson-spec.html))
- An implementation of the [\__geo_interface\__](https://gist.github.com/sgillies/2217756), a GeoJSON-like protocol for geo-spatial (GIS) vector data.

## Installation
```julia
Pkg.add("GeoJSON")
# Running Pkg.update() will always give you the freshest version of GeoJSON
# Double-check that it works:
Pkg.test("GeoJSON")
```

## Basic Usage
Although we use GeoInterface types for representing GeoJSON objects, it works in tandem with the [JSON.jl](https://github.com/JuliaIO/JSON.jl) package, for parsing ~~and printing~~ objects. Here are some examples of its functionality:

- Parses a GeoJSON String or IO stream into a GeoInterface object
```julia
julia> using GeoJSON
julia> osm_buildings = """{
                "type": "FeatureCollection",
                "features": [{
                  "type": "Feature",
                  "geometry": {
                    "type": "Polygon",
                    "coordinates": [
                      [
                        [13.42634, 52.49533],
                        [13.42660, 52.49524],
                        [13.42619, 52.49483],
                        [13.42583, 52.49495],
                        [13.42590, 52.49501],
                        [13.42611, 52.49494],
                        [13.42640, 52.49525],
                        [13.42630, 52.49529],
                        [13.42634, 52.49533]
                      ]
                    ]
                  },
                  "properties": {
                    "color": "rgb(255,200,150)",
                    "height": 150
                  }
                }]
              }"""
julia> buildings = GeoJSON.parse(osm_buildings) # GeoJSON.parse -- parse a GeoJSON string or stream
GeoInterface.FeatureCollection{GeoInterface.Feature}(GeoInterface.Feature[GeoInterface.Feature(GeoInterface.Polygon(Array{Array{Float64,1},1}[Array{Float64,1}[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]]),Dict{String,Any}(Pair{String,Any}("height",150),Pair{String,Any}("color","rgb(255,200,150)")))],nothing,nothing)
```
Use `GeoJSON.parsefile("tech_square.geojson")` to read GeoJSON files from disk.

- Transforms a GeoInterface object into a nested Array or Dict

```julia
julia> dict = geo2dict(buildings) # geo2dict -- GeoInterface object to Dict/Array-representation
Dict{String,Any} with 2 entries:
  "features" => Dict{String,Any}[Dict{String,Any}(Pair{String,Any}("geometry",Dict{String,Any}(Pair{String,Any}("coordi…
  "type"     => "FeatureCollection"

julia> JSON.parse(osm_buildings) # should be comparable (if not the same)
Dict{String,Any} with 2 entries:
  "features" => Any[Dict{String,Any}(Pair{String,Any}("geometry",Dict{String,Any}(Pair{String,Any}("coordinates",Any[An…
  "type"     => "FeatureCollection"
```

- Transforms from a nested Array/Dict to a GeoInterface object

```julia
julia> dict2geo(dict)
GeoInterface.FeatureCollection{GeoInterface.Feature}(GeoInterface.Feature[GeoInterface.Feature(GeoInterface.Polygon(Array{Array{Float64,1},1}[Array{Float64,1}[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]]),Dict{String,Any}(Pair{String,Any}("height",150),Pair{String,Any}("color","rgb(255,200,150)")))],nothing,nothing)

julia> GeoJSON.parse(osm_buildings) # the original object (for comparison)
GeoInterface.FeatureCollection{GeoInterface.Feature}(GeoInterface.Feature[GeoInterface.Feature(GeoInterface.Polygon(Array{Array{Float64,1},1}[Array{Float64,1}[[13.4263,52.4953],[13.4266,52.4952],[13.4262,52.4948],[13.4258,52.495],[13.4259,52.495],[13.4261,52.4949],[13.4264,52.4952],[13.4263,52.4953],[13.4263,52.4953]]]),Dict{String,Any}(Pair{String,Any}("height",150),Pair{String,Any}("color","rgb(255,200,150)")))],nothing,nothing)
```

- Writing back GeoJSON strings is not yet implemented

## GeoInterface
This library implements the [GeoInterface](https://github.com/JuliaGeo/GeoInterface.jl).
For more information on the types that are returned by this package, and the methods that can be
used on them, refer to the documentation of the GeoInterface package.
