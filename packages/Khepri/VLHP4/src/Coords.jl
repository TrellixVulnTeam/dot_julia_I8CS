
using StaticArrays
using LinearAlgebra
import LinearAlgebra.cross, LinearAlgebra.dot


export Loc, Locs, LocOrZ,
       Vec, Vecs, VecOrZ,
       XYZ, xyz, cyl, sph,
       VXYZ, vxyz, vcyl, vsph,
       world_cs,
       current_cs,
       distance,
       u0,ux,uy,uz,uxy,uyz,uxz,uxyz,
       x,y,z,
       xy,xz,yz,pol,cyl,sph,
       cx,cy,cz,
       pol_rho, pol_phi,
       cyl_rho,cyl_phi,cyl_z,
       sph_rho,sph_phi,sph_psi,
       vx,vy,vz,
       vxy,vxz,vyz,vpol,vcyl,vsph,
       add_x,add_y,add_z,add_xy,add_xz,add_yz,add_xyz,
       unitized,
       cs_from_o_vx_vy_vz,
       cs_from_o_vx_vy,
       cs_from_o_vz,
       cs_from_o_phi,
       loc_from_o_vx_vy,
       loc_from_o_vz,
       loc_from_o_phi,
       min_loc, max_loc,
       is_world_cs,
       in_cs, in_world,
       intermediate_loc,
       meta_program,
       translated_cs,
       scaled_cs,
       center_scaled_cs,
       translating_current_cs,
       regular_polygon_vertices

Vec4f = SVector{4,Float64}
Mat4f = SMatrix{4,4,Float64}
struct CS
  transform::Mat4f
end

translated_cs(cs::CS, x::Real, y::Real, z::Real) =
    CS(cs.transform * SMatrix{4,4,Float64}([
        1 0 0 x;
        0 1 0 y;
        0 0 1 z;
        0 0 0 1]))

scaled_cs(cs::CS, x::Real, y::Real, z::Real) =
    CS(cs.transform * SMatrix{4,4,Float64}([
        x 0 0 0;
        0 y 0 0;
        0 0 z 0;
        0 0 0 1]))

center_scaled_cs(cs::CS, x::Real, y::Real, z::Real) =
    let xt = cs.transform[4,1]
        yt = cs.transform[4,2]
        zt = cs.transform[4,3]
        translated_cs(
            scaled_cs(
                translated_cs(cs, -xt, -yt, -zt),
                x, y, z),
            xt, yt, zt)
    end

global const world_cs = CS(Mat4f(I))
global const current_cs = Parameter(world_cs)

is_world_cs(cs::CS) = cs ===  world_cs

translating_current_cs(f, _dx::Real=0, _dy::Real=0, _dz::Real=0; dx::Real=_dx, dy::Real=_dy, dz::Real=_dz) =
    with(current_cs, translated_cs(current_cs(), dx, dy, dz)) do
        f()
    end



abstract type Loc end
abstract type Vec end

Base.zero(::Type{<:Loc}) = u0()

#ideally, this should be Vector{Loc} but empty vectors of Loc are
#actually of type Vector{Any}
const Locs = Vector{<:Loc}
const Vecs = Vector{<:Vec}

#Base.==(cs0::CS, cs1::CS) = (cs0 === cs1) || (cs0.transform == cs1.transform)

#translation_matrix(x::Real, y::Real, z::Real) = CS(SMatrix{4,4,Float64}())

struct XYZ <: Loc
  x::Real
  y::Real
  z::Real
  cs::CS
  raw::Vec4f
end

Base.show(io::IO, loc::XYZ) =
    print(io, "xyz($(loc.x),$(loc.y),$(loc.z)$(loc.cs == world_cs ? "" : ", ..."))")

#import Base.getfield, Base.Field
#getfield(p::XYZ, ::Field{:cyl_rho}) = hypot(p.x, p.y)

xyz(x,y,z,cs=current_cs()) =
  XYZ(x,y,z,cs,Vec4f(convert(Float64,x),convert(Float64,y),convert(Float64,z), 1.0))

xyz(s::Vec4f,cs::CS) =
  XYZ(s[1], s[2], s[3], cs, s)

scaled_cs(p::XYZ, x::Real, y::Real, z::Real) = xyz(p.x, p.y, p.z, scaled_cs(p.cs, x, y, z))
center_scaled_cs(p::XYZ, x::Real, y::Real, z::Real) = xyz(p.x/x, p.y/y, p.z/z, center_scaled_cs(p.cs, x, y, z))


cx(p) = p.x
cy(p) = p.y
cz(p) = p.z

cyl(rho::Real, phi::Real, z::Real, cs::CS=current_cs()) =
  xyz(rho*cos(phi), rho*sin(phi), z, cs)
add_cyl(p::Loc, rho::Real, phi::Real, z::Real) =
  p + vcyl(rho, phi, z, p.cs)
cyl_rho(p) =
  let (x, y) = (p.x, p.y)
    sqrt(x*x + y*y)
  end
cyl_phi(p) = sph_phi(p)
cyl_z(p) = p.z

pol(rho::Real, phi::Real, cs::CS=current_cs()) =
  cyl(rho, phi, 0, cs)
add_pol(p::Loc, rho::Real, phi::Real) =
  p + vcyl(rho, phi, 0)
pol_rho = cyl_rho
pol_phi = cyl_phi

sph(rho::Real, phi::Real, psi::Real, cs::CS=current_cs()) =
  let sin_psi = sin(psi)
    xyz(rho*cos(phi)*sin_psi, rho*sin(phi)*sin_psi, rho*cos(psi), cs)
  end
add_sph(p::Loc, rho::Real, phi::Real, psi::Real) =
  p + vsph(rho, phi, psi, p.cs)
sph_rho(p) =
  let (x, y, z) = (p.x, p.y, p.z)
    sqrt(x*x + y*y + z*z)
  end
sph_phi(p) =
  let (x, y) = (p.x, p.y)
    0 == x == y ? 0 : mod(atan(y, x),2pi)
  end
sph_psi(p) =
  let (x, y, z) = (p.x, p.y, p.z)
    0 == x == y == z ? 0 : mod(atan2(sqrt(x*x + y*y), z),2pi)
  end

struct VXYZ <: Vec
    x::Real
    y::Real
    z::Real
    cs::CS
    raw::SVector{4,Float64}
end

Base.show(io::IO, vec::VXYZ) =
    print(io, "vxyz($(vec.x),$(vec.y),$(vec.z)$(vec.cs == world_cs ? "" : ", ..."))")


vxyz(x,y,z,cs=current_cs()) =
  VXYZ(x,y,z,cs,Vec4f(convert(Float64,x),convert(Float64,y),convert(Float64,z), 0.0))
vxyz(s::Vec4f,cs::CS) = VXYZ(s[1], s[2], s[3], cs, s)

vcyl(rho::Real, phi::Real, z::Real, cs::CS=current_cs()) =
  vxyz(rho*cos(phi), rho*sin(phi), z, cs)
add_vcyl(v::Vec, rho::Real, phi::Real, z::Real) =
  v + vcyl(rho, phi, z, v.cs)

vpol(rho::Real, phi::Real, cs::CS=current_cs()) =
  vcyl(rho, phi, 0, cs)
add_vpol(v::Vec, rho::Real, phi::Real) =
  add_vcyl(v, rho, phi, 0)

vsph(rho::Real, phi::Real, psi::Real, cs::CS=current_cs()) =
  let sin_psi = sin(psi)
    vxyz(rho*cos(phi)*sin_psi, rho*sin(phi)*sin_psi, rho*cos(psi), cs)
  end
add_vsph(v::Vec, rho::Real, phi::Real, psi::Real) =
  v + vsph(rho, phi, psi, v.cs)

unitized(v::Vec) = vxyz(v.raw./sqrt(sum(abs2, v.raw)), v.cs)

in_cs(from_cs::CS, to_cs::CS) =
    to_cs == world_cs ?
        from_cs.transform :
        inv(from_cs.transform) * to_cs.transform

in_cs(p::Loc, cs::CS) =
  p.cs == cs ?
    p :
    cs == world_cs ?
      xyz(p.cs.transform * p.raw, world_cs) :
      xyz(inv(p.cs.transform) * cs.transform * p.raw, cs)

in_cs(p::Vec, cs::CS) =
  p.cs == cs ?
    p :
    cs == world_cs ?
      vxyz(p.cs.transform * p.raw, world_cs) :
      vxyz(inv(p.cs.transform) * cs.transform * p.raw, cs)

in_cs(p, q) = in_cs(p, q.cs)

in_world(p) = in_cs(p, world_cs)

export inverse_transformation
inverse_transformation(p::Loc) = xyz(0,0,0, CS(inv(translated_cs(p.cs, p.x, p.y, p.z).transform)))


#loc_in_world(p::Loc) = p.cs == world_cs ? p : xyz(p.cs.transform * p.raw, world_cs)
#loc_in(p::Loc, cs::CS) = xyz(inv(p.cs.transform) * loc_in_world(p).raw, cs)
#loc_in(p::Loc, q::Loc) = loc_in(p, q.cs)

#vec_in_world(p::Loc) = p.cs == world_cs ? p : vxyz(p.cs.transform * p.raw, world_cs)
#vec_in(p::Loc, cs::CS) = vxyz(inv(p.cs.transform) * vec_in_world(p).raw, cs)
#vec_in(p::Loc, q::Loc) = vec_in(p, q.cs)



cs_from_o_vx_vy_vz(o::Loc, ux::Vec, uy::Vec, uz::Vec) =
  CS(SMatrix{4,4,Float64}(ux.x, ux.y, ux.z, 0, uy.x, uy.y, uy.z, 0, uz.x, uz.y, uz.z, 0, o.x, o.y, o.z, 1))

LinearAlgebra.cross(v::Vec, w::Vec) = _cross(v.raw, in_cs(w, v.cs).raw, v.cs)
_cross(a::Vec4f, b::Vec4f, cs::CS) =
  vxyz(a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1], cs)

LinearAlgebra.dot(v::Vec, w::Vec) = _dot(v.raw, in_cs(w, v.cs).raw)
_dot(a::Vec4f, b::Vec4f) =
  a[1]*b[1] + a[2]*b[2] + a[3]*b[3]

cs_from_o_vx_vy(o::Loc, vx::Vec, vy::Vec) =
  let o = in_world(o),
    vx = unitized(in_world(vx)),
    vz = unitized(cross(vx, in_world(vy)))
    cs_from_o_vx_vy_vz(o, vx, cross(vz,vx), vz)
  end

cs_from_o_vz(o::Loc, n::Vec) =
  let o = in_world(o),
      n = in_world(n),
      vx = vpol(1, sph_phi(n) + pi/2, o.cs),
      vy = unitized(cross(n, vx)),
      vz = unitized(n)
    cs_from_o_vx_vy_vz(o, vx, vy, vz)
  end

cs_from_o_phi(o::Loc, phi::Real) =
  let vx = in_world(vcyl(1, phi, 0, o.cs))
      vy = in_world(vcyl(1, phi + pi/2, 0, o.cs))
      vz = cross(vx, vy)
      o = in_world(o)
      cs_from_o_vx_vy_vz(o, vx, vy, vz)
  end

loc_from_o_vx_vy(o::Loc, vx::Vec, vy::Vec) = u0(cs_from_o_vx_vy(o, vx, vy))
loc_from_o_vz(o::Loc, vz::Vec) = u0(cs_from_o_vz(o, vz))
loc_from_o_phi(o::Loc, phi::Real) = u0(cs_from_o_phi(o, phi))

#To handle the common case
maybe_loc_from_o_vz(o::Loc, n::Vec) =
  let n = in_world(n)
    if n.x == 0 && n.y == 0
      o
    else
      loc_from_o_vz(o, n)
    end
  end

import Base.+, Base.-, Base.*, Base./, Base.length
#This is not needed!
#(+){T1,T2,T3,T4,T5,T6}(p::XYZ{T1,T2,T3},v::VXYZ{T4,T5,T6}) = xyz(p.x+v.x, p.y+v.y, p.z+v.z, p.raw+v.raw)


add_x(p,x) = xyz(p.x+x, p.y, p.z, p.cs)
add_y(p,y) = xyz(p.x, p.y+y, p.z, p.cs)
add_z(p,z) = xyz(p.x, p.y, p.z+z, p.cs)
add_xy(p,x,y) = xyz(p.x+x, p.y+y, p.z, p.cs)
add_xz(p,x,z) = xyz(p.x+x, p.y, p.z+z, p.cs)
add_yz(p,y,z) = xyz(p.x, p.y+y, p.z+z, p.cs)
add_xyz(p,x,y,z) = xyz(p.x+x, p.y+y, p.z+z, p.cs)

(+)(a::XYZ,b::VXYZ) = xyz(a.raw + in_cs(b, a.cs).raw, a.cs)
(+)(a::VXYZ,b::XYZ) = xyz(a.raw + in_cs(b, a.cs).raw, a.cs)
(+)(a::VXYZ,b::VXYZ) = vxyz(a.raw + in_cs(b, a.cs).raw, a.cs)
(-)(a::XYZ,b::VXYZ) = xyz(a.raw - in_cs(b, a.cs).raw, a.cs)
(-)(a::VXYZ,b::VXYZ) = vxyz(a.raw - in_cs(b, a.cs).raw, a.cs)
(-)(a::XYZ,b::XYZ) = vxyz(a.raw - in_cs(b, a.cs).raw, a.cs)
(-)(a::VXYZ) = vxyz(-a.raw, a.cs)
(*)(a::VXYZ,b::Real) = vxyz(a.raw * b, a.cs)
(/)(a::VXYZ,b::Real) = vxyz(a.raw / b, a.cs)

length(v::Vec) = norm(v.raw)

min_loc(p::Loc, q::Loc) =
    xyz(min.(p.raw, in_cs(q, p.cs).raw), p.cs)
max_loc(p::Loc, q::Loc) =
    xyz(max.(p.raw, in_cs(q, p.cs).raw), p.cs)

distance(p::XYZ, q::XYZ) = norm((in_world(q)-in_world(p)).raw)

u0(cs=current_cs()) = xyz(0,0,0,cs)
ux(cs=current_cs()) = xyz(1,0,0,cs)
uy(cs=current_cs()) = xyz(0,1,0,cs)
uz(cs=current_cs()) = xyz(0,0,1,cs)
uxy(cs=current_cs()) = xyz(1,1,0,cs)
uyz(cs=current_cs()) = xyz(0,1,1,cs)
uxz(cs=current_cs()) = xyz(1,0,1,cs)
uxyz(cs=current_cs()) = xyz(1,1,1,cs)

x(x::Real=1,cs=current_cs()) = xyz(x,0,0,cs)
y(y::Real=1,cs=current_cs()) = xyz(0,y,0,cs)
z(z::Real=1,cs=current_cs()) = xyz(0,0,z,cs)
xy(x::Real=1,y::Real=1,cs=current_cs()) = xyz(x,y,0,cs)
yz(y::Real=1,z::Real=1,cs=current_cs()) = xyz(0,y,z,cs)
xz(x::Real=1,z::Real=1,cs=current_cs()) = xyz(x,0,z,cs)

vx(x::Real=1,cs=current_cs()) = vxyz(x,0,0,cs)
vy(y::Real=1,cs=current_cs()) = vxyz(0,y,0,cs)
vz(z::Real=1,cs=current_cs()) = vxyz(0,0,z,cs)
vxy(x::Real=1,y::Real=1,cs=current_cs()) = vxyz(x,y,0,cs)
vyz(y::Real=1,z::Real=1,cs=current_cs()) = vxyz(0,y,z,cs)
vxz(x::Real=1,z::Real=1,cs=current_cs()) = vxyz(x,0,z,cs)

position_and_height(p, q) = loc_from_o_vz(p, q - p), distance(p, q)

regular_polygon_vertices(edges::Integer=3, center::Loc=u0(), radius::Real=1, angle::Real=0, is_inscribed::Bool=false) = begin
  r = is_inscribed ? radius : radius/cos(pi/edges)
  [center + vpol(r, a, center.cs) for a in division(angle, angle + 2*pi, edges, false)]
end

intermediate_loc(p::Loc, q::Loc, f::Real=0.5) =
  if p.cs == q.cs
    p+(q-p)*f
  else
    o = intermediate_loc(in_world(p), in_world(q), f)
    v_x = in_world(vx(1, p.cs))*(1-f) + in_world(vx(1, q.cs))*f
    v_y = in_world(vy(1, p.cs))*(1-f) + in_world(vy(1, q.cs))*f
    loc_from_o_vx_vy(o, v_x, v_y)
  end

# Metaprogramming

meta_program(x::Any) = x # literals might be self evaluating
meta_program(x::Real) = signif(x,8)
meta_program(x::Bool) = x
meta_program(x::Vector) = Expr(:vect, map(meta_program, x)...)
meta_program(p::Loc) =
    if cz(p) == 0
        Expr(:call, :xy, meta_program(cx(p)), meta_program(cy(p)))
    else
        Expr(:call, :xyz, meta_program(cx(p)), meta_program(cy(p)), meta_program(cz(p)))
    end
meta_program(v::Vec) =
    if cz(p) == 0
        Expr(:call, :vxy, meta_program(cx(p)), meta_program(cy(p)))
    else
        Expr(:call, :vxyz, meta_program(cx(p)), meta_program(cy(p)), meta_program(cz(p)))
    end
