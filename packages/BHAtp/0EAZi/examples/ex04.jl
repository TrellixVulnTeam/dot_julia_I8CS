using Compat, BHAtp

ProjDir = dirname(@__FILE__)

#=
This example uses a downwards z-axis, an x-axis to the right and an y-axis coming towards you

Distributed force in -x direction and in +z-direction (simple representation of element weights)

Iterate while adapting wall boundary forces
=#

#=
Compare formulas at:
http://www.awc.org/pdf/codes-standards/publications/design-aids/AWC-DA6-BeamFormulas-0710.pdf
=#

N = 200                  # No of elements
L = 40                     # [m]
W = 2000.0            # Total weight of string [N]
Np1 = N + 1
Nhp1 = Int(N/2) + 1

data = Dict(
  # Frame(nels, nn, ndim, nst, nip, finite_element(nod, nodof))
  :struc_el => Frame(N, Np1, 3, 1, 1, Line(2, 3)),
  :properties => [1.0e6 1.0e6 1.0e6 3.0e5;],
  :y_coords => zeros(Np1),
  :x_coords => zeros(Np1),
  :g_num => [
    collect(1:N)';
    collect(2:Np1)'],
  :support => [
    (1, [0 0 0 0 0 0]),
    (Int(N/2),  [0 0 1 0 1 0]),
    (Int(3N/4),  [0 0 1 0 1 0]),
    (Np1, [1 0 1 0 1 0]),
    ],
  :loaded_nodes => [(i, [-W/Np1 0.0 W/Np1 0.0 0.0 0.0]) for i in 1:Np1]
)

data[:z_coords] = VERSION.minor < 7 ? linspace(0, L, Np1) :  range(0, stop=L, length=Np1)

count = 0
while count < 6
  @time m, dis_df, fm_df = p44_1(data)
  #display(dis_df)
  if m.displacements[1, 13] > 0.0002
    #@show data[:loaded_nodes][13][2][1]
    data[:loaded_nodes][13][2][1] += -200.0
  else
    break
  end
  count +=1
end

data |> display
println()

m, dis_df, fm_df = p44_1(data)

println("Displacements:")
display(dis_df)
println()

#=
println("Actions:")
display(fm_df)
println()
=#

using Plots
gr(size=(400,600))

p = Vector{Plots.Plot{Plots.GRBackend}}(3)
p[1] = plot(m.z_coords, m.displacements[1,:], ylim=(-0.1, 0.1), lab="Displacement", 
 xlabel="x [m]", ylabel="deflection [m]", color=:red)
p[2] = plot(m.actions[1,:], lab="Shear force", ylim=(-1000, 2000), xlabel="element",
  ylabel="shear force [N]", palette=:greens,fill=(0,:auto),α=0.6)
p[3] = plot(m.actions[11,:], lab="Moment", ylim=(-4200, 3000), xlabel="element",
  ylabel="moment [Nm]", palette=:grays,fill=(0,:auto),α=0.6)

plot(p..., layout=(3, 1))
savefig(ProjDir*"/figure-04.png")
#=
plot!()
gui()
=#

