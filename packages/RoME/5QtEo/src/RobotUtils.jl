

mutable struct RangeAzimuthElevation
  range::Float64
  azimuth::Float64
  elevation::Union{Nothing,Float64}
end

function convert(::Type{Rotations.Quat}, q::TransformUtils.Quaternion)
  Rotations.Quat(q.s, q.v...)
end
function convert(::Type{Rotations.Quat}, x::SO3)
  q = convert(TransformUtils.Quaternion, x)
  convert(Rotations.Quat, q)
end
function convert(::Type{T}, x::SO3) where {T <: CoordinateTransformations.AffineMap}
  LinearMap( convert(Quat, x) )
end

function convert(::Type{T}, x::SE3) where {T <: CoordinateTransformations.AffineMap}
  Translation(x.t...) ∘ convert(AffineMap{Rotations.Quat{Float64}}, x.R)
end
function convert(::Type{SE3}, x::T) where {T <: CoordinateTransformations.AffineMap{Rotations.Quat{Float64}}}
  SE3(x.translation[1:3], TransformUtils.Quaternion(x.linear.w, [x.linear.x,x.linear.y,x.linear.z]) )
end

function convert(::Type{SE3}, t::Tuple{Symbol, Vector{Float64}})
  if t[1]==:XYZqWXYZ
    return SE3(t[2][1:3],TransformUtils.Quaternion(t[2][4],t[2][5:7]))
  else
    error("Unknown conversion type $(t[1])")
  end
end

function convert(::Type{RangeAzimuthElevation}, val::Tuple{Symbol, Vector{Float64}})
  if val[1] == :rangeazimuth
    return RangeAzimuthElevation(val[2][1],val[2][2],nothing)
  elseif val[1] == :rangeazimuthelevation
    return RangeAzimuthElevation(val[2][1],val[2][2],val[2][3])
  else
    error("Unknown conversion from $(val[1]) to RangeAzimuthElevation.")
  end
end

# should be deprecated or indicated more clearly
lsrBR(a) = [a[2,:];a[1,:]]';

function veePose3(s::SE3)
  TransformUtils.veeEuler(s)
end
function veePose(s::SE3)
  TransformUtils.veeEuler(s)
end


function \(s::SE3, wTr::CTs.Translation)
  bTr = s.R.R'*(wTr.v-s.t)
  Dtr = bTr
  range = norm(Dtr)
  azi = atan(Dtr[2], Dtr[1])
  elev = atan(Dtr[3], Dtr[1])
  RangeAzimuthElevation(range, azi, elev)
end




"""
    $(SIGNATURES)

Calculate the cartesian distance between two vertices in the graph using their symbol name, and by maximum belief point.
"""
function getRangeKDEMax2D(fgl::FactorGraph, vsym1::Symbol, vsym2::Symbol)
  x1 = getKDEMax(getVertKDE(fgl, vsym1))
  x2 = getKDEMax(getVertKDE(fgl, vsym2))
  norm(x1[1:2]-x2[1:2])
end

function measureMeanDist(fg::FactorGraph, a::T, b::T) where {T <: AbstractString}
    #bearrang!(residual::Array{Float64,1}, Z::Array{Float64,1}, X::Array{Float64,1}, L::Array{Float64,1})
    res = zeros(2)
    A = getVal(fg,a)
    B = getVal(fg,b)
    Ax = Statistics.mean(vec(A[1,:]))
    Ay = Statistics.mean(vec(A[2,:]))
    Bx = Statistics.mean(vec(B[1,:]))
    By = Statistics.mean(vec(B[2,:]))
    dx = Bx - Ax
    dy = By - Ay
    b = atan(dy,dx)
    r = sqrt(dx^2 + dy^2)
    return r, b
end

function predictBodyBR(fg::FactorGraph, a::T, b::T) where {T <: AbstractString}
  res = zeros(2)
  A = getVal(fg,a)
  B = getVal(fg,b)
  Ax = Statistics.mean(vec(A[1,:]))
  Ay = Statistics.mean(vec(A[2,:]))
  Ath = Statistics.mean(vec(A[3,:]))
  Bx = Statistics.mean(vec(B[1,:]))
  By = Statistics.mean(vec(B[2,:]))
  wL = SE2([Bx;By;0.0])
  wBb = SE2([Ax;Ay;Ath])
  bL = se2vee((wBb \ Matrix{Float64}(LinearAlgebra.I, 3,3)) * wL)
  dx = bL[1] - 0.0
  dy = bL[2] - 0.0
  b = (atan(dy,dx))
  r = sqrt(dx^2 + dy^2)
  return b, r
end

function getNextLbl(fgl::FactorGraph, chr)
  # TODO convert this to use a double lookup
  max = -1
  maxid = -1
  for vid in fgl.IDs
  # for v in fgl.v #fgl.g.vertices # fgl.v
      v = (vid[2], fgl.g.vertices[vid[2]])
      if v[2].attributes["label"][1] == chr
        # TODO test for allnums first, ex. :x1_2
        val = parse(Int,v[2].attributes["label"][2:end])
        if max < val
          max = val
          maxid = v[1]
        end
      end
  end
  if maxid != -1
    v = getVert(fgl,maxid)
    X = getVal(v)
    return v, X, Symbol(string(chr,max+1))
  else
    return nothing, nothing, Symbol(string(chr,max+1)) # Union{}
  end
end

function getLastPose(fgl::FactorGraph)
  return getNextLbl(fgl, 'x')
end
getLastPose2D(fgl::FactorGraph) = getLastPose(fgl)

function getlastpose(slam::SLAMWrapper)
  error("getlastpose -- Not implemented yet")
end


function getLastLandm2D(fgl::FactorGraph)
  return getNextLbl(fgl, 'l')
end

function odomKDE(p1,dx,cov)
  X = getPoints(p1)
  sig = diag(cov)
  RES = zeros(size(X))
  # increases the number of particles based on the number of modes in the measurement Z
  for i in 1:size(X,2)
      ent = [randn()*sig[1]; randn()*sig[2]; randn()*sig[3]]
      RES[:,i] = addPose2Pose2(X[:,i], dx + ent)
  end
  return kde!(RES, "lcv")
end

"""
    $(SIGNATURES)

Create a new variable node and insert odometry constraint factor between
which will automatically increment latest pose symbol x<k+1> for new node new node and
constraint factor are returned as a tuple.
"""
function addOdoFG!(fg::G,
                   n::Symbol,
                   DX::Array{Float64,1},
                   cov::Array{Float64,2};
                   N::Int=0,
                   ready::Int=1,
                   labels::Vector{<:AbstractString}=String[]  ) where G <: AbstractDFG
    #
    prev, X, nextn = getLastPose2D(fg)
    r,c = size(X)
    if N==0
      N = c
    end
    sig = diag(cov)
    XnextInit = zeros(r,c)
    # increases the number of particles based on the number of modes in the measurement Z
    for i in 1:c
        ent = [randn()*sig[1]; randn()*sig[2]; randn()*sig[3]]
        XnextInit[:,i] = addPose2Pose2(X[:,i], DX + ent)
    end

    v = addVariable!(fg, n, Pose2, N=N, ready=ready, labels=[labels;"POSE"])
    # v = addVariable!(fg, n, XnextInit, cov, N=N, ready=ready, labels=labels)
    pp = Pose2Pose2(MvNormal(DX, cov)) #[prev;v],
    f = addFactor!(fg, [prev;v], pp, ready=ready, autoinit=true )
    infor = inv(cov^2)
    # addOdoRemote(prev.index,v.index,DX,infor) # this is for remote factor graph ref parametric solution -- skipped internally by global flag variable
    return v, f
end

function addOdoFG!(fgl::G,
                   Z::Pose3Pose3;
                   N::Int=0,
                   ready::Int=1,
                   labels::Vector{<:AbstractString}=String[]  ) where {G <: AbstractDFG}
  #
  vprev, X, nextn = getLastPose(fgl)
  vnext = addVariable!(fgl, nextn, Pose3, ready=ready, labels=labels)
  fact = addFactor!(fgl, [vprev;vnext], Z, autoinit=true)

  return vnext, fact

  # error("addOdoFG!( , ::Pose3Pose3, ) not currently usable, there were breaking changes. Work in Progress")
  # addOdoFG(fg, n, DX, cov, N=N, ready=ready, labels=labels)
end

"""
    $(SIGNATURES)

Create a new variable node and insert odometry constraint factor between
which will automatically increment latest pose symbol x<k+1> for new node new node and
constraint factor are returned as a tuple.

"""
function addOdoFG!(
        fgl::FactorGraph,
        odo::Pose2Pose2;
        N::Int=0,
        ready::Int=1,
        labels::Vector{<:AbstractString}=String[] ) # where {PP <: RoME.BetweenPoses}
    #
    vprev, X, nextn = getLastPose(fgl)
    if N==0
      N = size(X,2)
    end
    # vnext = addVariable!(fgl, nextn, X⊕odo, ones(1,1), N=N, ready=ready, labels=labels)
    vnext = addVariable!(fgl, nextn, Pose2, N=N, ready=ready, labels=labels)
    fact = addFactor!(fgl, [vprev;vnext], odo, autoinit=true)

    return vnext, fact
end

# """
#     $SIGNATURES
#
# Initialize an empty `::FactorGraph` object while initializing `sessionname`, `robotname`, and `cloudgraph`.
# """
# function initfg(;sessionname="NA",robotname="",username="",cloudgraph=nothing)
#   # fgl = RoME.initfg(sessionname=sessionname)
#   fgl = IIF.FactorGraph()
#   fgl.sessionname = sessionname
#   fgl.robotname = robotname
#   fgl.username = username
#   fgl.cg = cloudgraph
#   return fgl
# end
# function initfg(;sessionname="NA")
#   fgl = IIF.FactorGraph()
#   fgl.sessionname=sessionname
#   # fgl.robotname = ?
#   # registerCallback!(fgl, RoME.getSample) # RoME.evalPotention
#   return fgl
# end

"""
    $(SIGNATURES)

Initialize a factor graph object as Pose2, Pose3, or neither and returns variable and factor symbols as array.
"""
function initFactorGraph!(fg::G;
                          P0::Union{Array{Float64,2},Nothing}=nothing,
                          init::Union{Vector{Float64},Nothing}=nothing,
                          N::Int=100,
                          lbl::Symbol=:x0,
                          ready::Int=1,
                          firstPoseType=Pose2,
                          labels::Vector{Symbol}=Symbol[]) where G <: AbstractDFG
  #
  nodesymbols = Symbol[]
  if firstPoseType == Pose2
      init = init!=nothing ? init : zeros(3)
      P0 = P0!=nothing ? P0 : Matrix(Diagonal([0.03;0.03;0.001]))
      # init = vectoarr2(init)
      addVariable!(fg,lbl,Pose2,N=N,autoinit=true,ready=ready,labels=labels )
      push!(nodesymbols, lbl)
      # v1 = addVariable!(fg, lbl, init, P0, N=N, ready=ready, labels=labels)
      fctVert = addFactor!(fg, [lbl;], PriorPose2(MvNormal(init, P0)), ready=ready, labels=labels) #[v1],
      push!(nodesymbols, Symbol(fctVert.label))
  end
  if firstPoseType == Pose3
      init = init!=nothing ? init : zeros(6)
      P0 = P0!=nothing ? P0 : Matrix(Diagonal([0.03;0.03;0.03;0.001;0.001;0.001]))
      addVariable!(fg,lbl,Pose2,N=N,autoinit=true,ready=ready,labels=labels )
      push!(nodesymbols, lbl)
      # v1 = addVariable!(fg, lbl, init, P0, N=N, ready=ready, labels=labels)
      fctVert = addFactor!(fg, [lbl;], PriorPose3(MvNormal(init, P0)), ready=ready, labels=labels) #[v1],
      push!(nodesymbols, Symbol(fctVert.label))
  end
  return nodesymbols
end


function newLandm!(fg::FactorGraph, lm::T, wPos::Array{Float64,2}, sig::Array{Float64,2};
                  N::Int=100, ready::Int=1, labels::Vector{T}=String[]) where {T <: AbstractString}

    vert=addVariable!(fg, Symbol(lm), Point2, N=N, ready=ready, labels=union(["LANDMARK";], labels))
    # TODO -- need to confirm this function is updating the correct memory location. v should be pointing into graph
    # vert=addVariable!(fg, Symbol(lm), wPos, sig, N=N, ready=ready, labels=labels)

    vert.attributes["age"] = 0
    vert.attributes["maxage"] = 0
    vert.attributes["numposes"] = 0
    updateFullVert!(fg, vert)

    println("newLandm! -- added $(lm)")
    return vert
end

function updateLandmAge(vlm::Graphs.ExVertex, pose::T) where {T <: AbstractString}
  error("still working here")
end

function addBRFG!(fg::G,
                  pose::T,
                  lm::T,
                  br::Array{Float64,1},
                  cov::Array{Float64,2};
                  ready::Int=1  ) where {G <: AbstractDFG, T <: AbstractString}
  #
  vps = getVert(fg,pose)
  vlm = getVert(fg,lm)
  testlbl = vps.label*vlm.label
  for nei in getOutNeighbors(fg, vlm)
    if nei.label == testlbl
      # TODO -- makes function call brittle
      @warn "We already have $(testlbl), skipping this constraint"
      return nothing
    end
  end
  @show keys(vlm.attributes)
  np = vlm.attributes["numposes"]
  la = vlm.attributes["age"]
  nage = parse(Int,pose[2:end])
  vlm.attributes["numposes"] = np+1
  vlm.attributes["age"] = ((la*np)+nage)/(np+1)
  vlm.attributes["maxage"] = nage
  updateFullVert!(fg, vlm)


  pbr = Pose2Point2BearingRange(Normal(br[1], cov[1,1]), Normal(br[2],  cov[2,2]))  #{Normal, Normal}
  @show vps, vlm
  f = addFactor!(fg, [vps;vlm], pbr, ready=ready, autoinit=true ) #[vps;vlm],

  # only used for max likelihood unimodal tests.
  u, P = pol2cart(br[[2;1]], diag(cov))
  infor = inv(P^2)
  # addLandmMeasRemote(vps.index,vlm.index,u,infor) # for iSAM1 remote solution as reference
  return f
end

function addMMBRFG!(fg::G,
                    syms::Array{Symbol,1}, br::Array{Float64,1},
                    cov::Array{Float64,2}; w::Vector{Float64}=Float64[0.5;0.5],
                    ready::Int=1) where G <: AbstractDFG
    #
    # vps = getVert(fg,pose)
    # vlm1 = getVert(fg,lm[1])
    # vlm2 = getVert(fg,lm[2])

    pbr = Pose2Point2BearingRange(Normal(br[1],cov[1,1]),  Normal(br[2],cov[2,2]))
    syms = Symbol.([pose;lm...])
    f = addFactor!(fg, syms, pbr, multihypo=[1.0; w...], ready=ready, autoinit=true )
    return f
end


function projNewLandmPoints(vps::Graphs.ExVertex, br::Array{Float64,1}, cov::Array{Float64,2})
    # TODO -- convert to use Distributions and common projection function
    Xps = getVal(vps)
    lmPts = zeros(2,size(Xps,2))
    for i in 1:size(Xps,2)
        ent = [cov[1,1]*randn(); cov[2,2]*randn()]
        init = vec(Xps[1:2,i])+randn(2)
        lmPts[:,i] = solveLandm(br + ent, vec(Xps[:,i]), init)
    end
    return lmPts
end

function projNewLandm!(fg::G,
                       pose::T,
                       lm::T,
                       br::Array{Float64,1},
                       cov::Array{Float64,2};
                       addfactor=true,
                       N::Int=100,
                       ready::Int=1,
                       labels::Vector{T}=String[]  ) where {G <: AbstractDFG, T <: AbstractString}
    #
    vps = getVert(fg, pose)

    lmPts = projNewLandmPoints(vps, br, cov)
    vlm = newLandm!(fg, lm, lmPts, cov, N=N, ready=ready, labels=labels) # cov should not be required here
    if addfactor
      fbr = addBRFG!(fg, pose, lm, br, cov, ready=ready)
      return vlm, fbr
    end
    return vlm
end

function calcIntersectVols(fgl::G, predLm::BallTreeDensity;
                           currage=0, maxdeltaage=Inf) where G <: AbstractDFG
    # TODO upgrade to using MMD test
    # all landmarks of interest
    xx,ll = ls(fgl)
    # output result
    rr = Dict{String, RemoteRef}()
    fetchlist = String[]
    iv = Dict{String, Float64}()
    for l in ll
      pvlm = getVert(fgl,l)
      # TODO -- can be improved via query in DB case
      if currage - pvlm.attributes["maxage"] < maxdeltaage
        p = getVertKDE(fgl, l)
        rr[l] = remotecall(uppA(), intersIntgAppxIS, p,predLm)
        push!(fetchlist, l)
      else
        println("calcIntersectVols -- ignoring $(l) because maxdeltaage exceeded")
        iv[l] = 0
      end
    end
    max = 0
    maxl = String("")
    for l in fetchlist #ll
      # p = getVertKDE(fgl, l)
      # tv = intersIntgAppxIS(p,predLm)
      # iv[l] = tv
      tv = fetch(rr[l])
      iv[l] = tv
      if max < tv  max = tv; maxl = l; end
    end
    return iv, maxl
end

function maxIvWithoutID(ivs::Dict{String, Float64}, l::T) where {T <: AbstractString}
  max = 0
  maxl = String("")
  for i in ivs
    if max < i[2] && i[1] != l;  max = i[2]; maxl = i[1]; end
  end
  return maxl
end

# binary tests to distinguish how to automatically add a landmark to the existing factor graph
function doAutoEvalTests(fgl::G, ivs::Dict{T, Float64}, maxl::T, lmid::Int, lmindx::Int) where {G <: AbstractDFG, T <: AbstractString}
  maxAnyval = maxl != String("") ? ivs[maxl] : 0.0
  # maxid = fgl.IDs[maxl]
  lmidSugg = lmid != -1 # a landmark ID has been suggested
  maxAnyExists = maxAnyval > 0.03 # there is notable intersection with previous landm
  lmIDExists = haskey(fgl.v, lmid) # suggested lmid already in fgl
  newlmindx = lmindx
  if lmIDExists
    lmSuggLbl = String(getVert(fgl,lmid).label) # TODO -- wasteful
  else
    newlmindx = lmindx + 1
    lmSuggLbl = String(string('l',newlmindx))
  end
  maxl2 = lmIDExists ? maxIvWithoutID(ivs, lmSuggLbl) : String("")
  maxl2Exists = lmIDExists ? (maxl2 != "" ? ivs[maxl2] > 0.03 : false) : false # there is notable intersection with previous landm
  intgLmIDExists = lmIDExists ? ivs[lmSuggLbl] > 0.03 : false

  return lmidSugg, maxAnyExists, maxl2Exists, maxl2, lmIDExists, intgLmIDExists, lmSuggLbl, newlmindx
end


function evalAutoCases!(fgl::G, lmid::Int, ivs::Dict{T, Float64}, maxl::T,
                        pose::T, lmPts::Array{Float64,2}, br::Array{Float64,1}, cov::Array{Float64,2}, lmindx::Int;
                        N::Int=100, ready::Int=1 ) where {G <: AbstractDFG, T <: AbstractString}
  lmidSugg, maxAnyExists, maxl2Exists, maxl2, lmIDExists, intgLmIDExists, lmSuggLbl, newlmindx = doAutoEvalTests(fgl,ivs,maxl,lmid, lmindx)

  println("evalAutoCases -- found=$(lmidSugg), $(maxAnyExists), $(maxl2Exists), $(lmIDExists), $(intgLmIDExists)")

  vlm = Union{}; fbr = Union{};
  if (!lmidSugg && !maxAnyExists)
    #new landmark and UniBR constraint
    v,L,lm = getLastLandm2D(fgl)
    vlm = newLandm!(fgl, lm, lmPts, cov, N=N,ready=ready)
    fbr = addBRFG!(fgl, pose, lm, br, cov, ready=ready)
  elseif !lmidSugg && maxAnyExists
    # add UniBR to best match maxl
    vlm = getVert(fgl,maxl)
    fbr = addBRFG!(fgl, pose, maxl, br, cov, ready=ready)
  elseif lmidSugg && !maxl2Exists && !lmIDExists
    #add new landmark and add UniBR to suggested lmid
    vlm = newLandm!(fgl, lmSuggLbl, lmPts, cov, N=N, ready=ready)
    fbr = addBRFG!(fgl, pose, lmSuggLbl, br, cov, ready=ready)
  elseif lmidSugg && !maxl2Exists && lmIDExists && intgLmIDExists
    # doesn't self intesect with existing lmid, add UniBR to lmid
    vlm = getVert(fgl, lmid)
    fbr = addBRFG!(fgl, pose, lmSuggLbl, br, cov, ready=ready)
  elseif lmidSugg && maxl2Exists && !lmIDExists
    # add new landmark and add MMBR to both maxl and lmid
    vlm = newLandm!(fgl, lmSuggLbl, lmPts, cov, N=N, ready=ready)
    addMMBRFG!(fgl, pose, [maxl2;lmSuggLbl], br, cov, ready=ready)
  elseif lmidSugg && maxl2Exists && lmIDExists && intgLmIDExists
    # obvious case, add MMBR to both maxl and lmid. Double intersect might be the same thing
    println("evalAutoCases! -- obvious case is happening")
    addMMBRFG!(fgl, pose, [maxl2;lmSuggLbl], br, cov, ready=ready)
    vlm = getVert(fgl,lmSuggLbl)
  elseif lmidSugg && maxl2Exists && lmIDExists && !intgLmIDExists
    # odd case, does not intersect with suggestion, but does with some previous landm
    # add MMBR
    @warn "evalAutoCases! -- no self intersect with suggested $(lmSuggLbl) detected"
    addMMBRFG!(fgl, pose, [maxl;lmSuggLbl], br, cov, ready=ready)
    vlm = getVert(fgl,lmSuggLbl)
  elseif lmidSugg && !maxl2Exists && lmIDExists && !intgLmIDExists
  #   # landm exists but no intersection with existing or suggested lmid
  #   # may suggest some error
    @warn "evalAutoCases! -- no intersect with suggested $(lmSuggLbl) or map detected, adding  new landmark MM constraint incase"
    v,L,lm = getLastLandm2D(fgl)
    vlm = newLandm!(fgl, lm, lmPts, cov, N=N, ready=ready)
    addMMBRFG!(fgl, pose, [lm; lmSuggLbl], br, cov, ready=ready)
  else
    error("evalAutoCases! -- unknown case encountered, can reduce to this error to a warning and ignore user request")
  end

  return vlm, fbr, newlmindx
end

function addAutoLandmBR!(fgl::G,
                         pose::T,
                         lmid::Int,
                         br::Array{Float64,1},
                         cov::Array{Float64,2},
                         lmindx::Int;
                         N::Int=100,
                         ready::Int=1  ) where {G <: AbstractDFG, T <: AbstractString}
  #
  vps = getVert(fgl, pose)
  lmPts = projNewLandmPoints(vps, br, cov)
  lmkde = kde!(lmPts)
  currage = parse(Int, pose[2:end])
  ivs, maxl = calcIntersectVols(fgl, lmkde, currage=currage,maxdeltaage=10)

  # There are 8 cases of interest
  vlm, fbr, newlmindx = evalAutoCases!(fgl, lmid, ivs, maxl,pose,lmPts, br,cov,lmindx,N=N,ready=ready)

  return vlm, fbr, newlmindx
end

function malahanobisBR(measA, preA, cov::Array{Float64,2})
    # measure landmark with noise
    res = measA - preA
    mala2 = Union{}
    #Malahanobis distance
    if false
      lambda = cov \ Matrix{Float64}(LinearAlgebra.I, 2,2)
      mala2 = res' * lambda * res
    else
      mala2 = res' * (cov \ res)
    end

    mala = sqrt(mala2)
    return mala
end





# ------------------------------------
# Transfered from IncrementalInference



function get2DSamples(fg::G; #::Union{Symbol, S};
                      from::Int=0, to::Int=999999999,
                      minnei::Int=0,
                      varkey::Regex=r"x") where {G <: AbstractDFG, S <: AbstractString}
  #
  X = Array{Float64,1}()
  Y = Array{Float64,1}()

  # if sym = 'l', ignore single measurement landmarks
  allids = DFG.getVariableIds(fg, varkey)  # fg.IDs
  saids = DFG.sortVarNested(allids)
  for id in saids
    # vertlbl = string(id[1])
    vertlbl = string(id)
    # if vertlbl[1] == sym
      val = parse(Int,vertlbl[2:end])
      if from <= val && val <= to
        # if length( getOutNeighbors(fg, vertlbl[2] , needdata=true ) ) >= minnei
        if length( DFG.getNeighbors(fg, id ) ) >= minnei
          # if length(out_neighbors(fg.v[id[2]],fg.g)) >= minnei
          X=[X; vec(getVal(fg,id)[1,:]) ]
          Y=[Y; vec(getVal(fg,id)[2,:]) ]
        end
      end
    # end
  end
  return X,Y
end

# function getAll2D(fg, sym; minnei::Int=0)
#   @warn "getAll2D deprecated, use get2DSamples instead"
#   return get2DSamples(fg, sym, minnei=minnei )
# end

function get2DSampleMeans(fg::G,
                          varkey::Regex=r"x";
                          from::Int=0, to::Int=9999999999,
                          minnei::Int=0) where G <: AbstractDFG
  #
  X = Array{Float64,1}()
  Y = Array{Float64,1}()
  Th = Array{Float64,1}()
  LB = String[]

  # if sym = 'l', ignore single measurement landmarks
  allids = DFG.getVariableIds(fg, varkey)  # fg.IDs
  saids = DFG.sortVarNested(allids)
  mask = Array{Bool,1}(undef, length(saids))
  fill!(mask, false)
  count = 0
  for id in saids
    count += 1
    if length( DFG.getNeighbors(fg, id) ) >= minnei
      mask[count] = true
    end
    if from != 0 || to != 9999999999
      vertlbl = string(id)
        # TODO won't work with nested labels
        val = parse(Int,vertlbl[2:end])
        if !(from <= val && val <= to)
          mask[count] = false
        end
    end
  end
  # allIDs = sort(allIDs)

  for id in saids[mask]
    X=[X; Statistics.mean( vec( getVal(fg, id )[1,:] ) )]
    Y=[Y; Statistics.mean( vec( getVal(fg, id )[2,:] ) )]
    # crude test for pose
    if string(id)[1] == 'x'
      Th=[Th; Statistics.mean( vec( getVal(fg, id )[3,:] ) )]
    end
    push!(LB, string(id))
  end
  return X,Y,Th,LB
end

#draw landmark positions
function getAll2DMeans(fg, sym::Regex)
  return get2DSampleMeans(fg, sym )
end

function getAll2DPoses(fg::G) where G <: AbstractDFG
    return getAll2DSamples(fg, varkey=r"x" )
end

function get2DPoseSamples(fg::G; from::Int=0, to::Int=999999999) where G <: AbstractDFG
  return get2DSamples(fg, varkey=r"x", from=from, to=to )
end

function get2DPoseMeans(fg::G; from::Int=0, to::Int=999999999) where G <: AbstractDFG
  return get2DSampleMeans(fg, r"x", from=from, to=to )
end


function get2DPoseMax(fgl::G;
					  varkey::Regex=r"x",
                      from::Int=-99999999999, to::Int=9999999999 ) where G <: AbstractDFG
  #
  # xLB,ll = ls(fgl) # TODO add: from, to, special option 'x'
  xLB = DFG.getVariableIds(fgl, varkey)
  saids = DFG.sortVarNested(xLB)
  X = Array{Float64,1}()
  Y = Array{Float64,1}()
  Th = Array{Float64,1}()
  LB = String[]
  for slbl in saids
    lbl = string(slbl)
    if from <= parse(Int,lbl[2:end]) <=to
      mv = getKDEMax(getVertKDE(fgl,slbl))
      push!(X,mv[1])
      push!(Y,mv[2])
      push!(Th,mv[3])
      push!(LB, string(lbl))
    end
  end
  return X, Y, Th, LB
end


function get2DLandmSamples(fg::G;
                           from::Int=0,
                           to::Int=999999999,
                           minnei::Int=0 ) where G <: AbstractDFG
  #
  return get2DSamples(fg, varkey=r"l", from=from, to=to, minnei=minnei )
end

function get2DLandmMeans(fg::G;
                         from::Int=0, to::Int=999999999,
                         minnei::Int=0) where G <: AbstractDFG
  #
  return get2DSampleMeans(fg, r"l", from=from, to=to, minnei=minnei )
end

function removeKeysFromArr(fgl::G,
                           torm::Array{Int,1},
                           lbl::Array{String,1}) where G <: AbstractDFG
  #
  retlbs = String[]
  for i in 1:length(lbl)
    id = parse(Int,lbl[i][2:end])
    if something(findfirst(isequal(id), torm), 0) == 0 #findfirst(torm,id) == 0
      push!(retlbs, lbl[i])
    else
      println("removeKeysFromArr -- skipping $(lbl[i]), id=$(id)")
    end
  end
  return retlbs
end
function removeKeysFromArr(fgl::G,
                           torm::Array{Int,1},
                           lbl::Array{Symbol,1} ) where G
  #
  removeKeysFromArr(fgl, torm, string.(lbl))
end

function get2DLandmMax(fgl::G;
                       from::Int=-99999999999,
                       to::Int=9999999999,
                       showmm=false, MM::Dict{Int,T}=Dict{Int,Int}()) where {G <: AbstractDFG, T}
  #
  # xLB,lLB = ls(fgl) # TODO add: from, to, special option 'x'
  lLB = DFG.getVariableIds(fgl, r"l")
  if !showmm lLB = removeKeysFromArr(fgl, collect(keys(MM)), lLB); end
  X = Array{Float64,1}()
  Y = Array{Float64,1}()
  Th = Array{Float64,1}()
  LB = String[]
  for lb in lLB
    @show lb
    lbl = string(lb)
    if from <= parse(Int,lbl[2:end]) <=to
      mv = getKDEMax(getVertKDE(fgl, Symbol(lb)))
      push!(X,mv[1])
      push!(Y,mv[2])
      push!(LB, string(lbl))
    end
  end
  return X, Y, Th, LB
end



# convenience function to add DIDSON sonar constraints to graph
function addLinearArrayConstraint(fgl::G,
                                  rangebearing::Union{Tuple{Float64, Float64}, Vector{Float64}},
                                  pose::Symbol,
                                  landm::Symbol ;
                                  rangecov::Float64=3e-4,
                                  bearingcov::Float64=3e-4 ) where G <: AbstractDFG

  #

  cl = LinearRangeBearingElevation((rangebearing[1],rangecov),(rangebearing[2],bearingcov))
  if !haskey(fgl.IDs, landm)
    pts = getVal(fgl, pose) + cl
    N = size(pts,2)
    vl1 = addVariable!(fgl, landm,  pts,  N=N)
    println("Automatically added $(landm) to the factor graph")
  end
  addFactor!(fgl, [getVert(fgl, pose); getVert(fgl, landm)], cl)
  nothing
end


function addSoftEqualityPoint2D(fgl::G,
                                l1::Symbol,
                                l2::Symbol;
                                dist=MvNormal([0.0;0.0],Matrix{Float64}(LinearAlgebra.I, 2,2)),
                                ready::Int=1  )  where G <: AbstractDFG
  #
  pp = Point2DPoint2D(dist)
  addFactor!(fgl, [l1,l2], pp, ready=ready)
end

"""
    $SIGNATURES

Build a basic factor graph in Pose2 with two `Pose2` and one landmark `Point2` variables,
along with `PriorPose2` on `:x0` and `Pose2Pose2` to `:x1`.  Also a `Pose2Point2BearingRange`
to landmark `:l1`.
"""
function basicFactorGraphExample(::Type{Pose2}=Pose2; addlandmark::Bool=true)
  fg = initfg()

  addVariable!(fg, :x0, Pose2)
  addVariable!(fg, :x1, Pose2)
  !addlandmark ? nothing : addVariable!(fg, :l1, Point2)

  addFactor!(fg, [:x0], PriorPose2(MvNormal([0;0;0.0],Matrix(Diagonal([1.0;1.0;0.01])))))
  addFactor!(fg, [:x0;:x1], Pose2Pose2(MvNormal([10.0;0;0.0],Matrix(Diagonal([1.0;1.0;0.01])))))
  !addlandmark ? nothing : addFactor!(fg, [:x1;:l1], Pose2Point2BearingRange(Normal(0.0,0.01), Normal(20.0, 1.0)))

  return fg
end
