"""
    GAMBAR

Gyromagnetic ratio for ¹H with units Hz/G.
"""
const GAMBAR = 4258

"""
    GAMMA

Gyromagnetic ratio for ¹H with units rad/s/G.
"""
const GAMMA  = 2π * GAMBAR

"""
    AbstractSpin

Abstract type for representing individual spins.
"""
abstract type AbstractSpin end

"""
    Spin([M,] M0, T1, T2, Δf[, pos]) <: AbstractSpin

Create an object that represents a single spin.

# Properties
- `M::Vector{Float64} = [0.0, 0.0, M0]`: Magnetization vector [Mx, My, Mz]
- `M0::Real`: Equilibrium magnetization
- `T1::Real`: Spin-lattice recovery time constant (ms)
- `T2::Real`: Spin-spin recovery time constant (ms)
- `Δf::Real`: Off-resonance frequency (Hz)
- `pos::Vector{<:Real} = [0, 0, 0]`: Spatial location [x, y, z] (cm)
- `signal::Complex{Float64}`: Signal produced by the spin

# Examples
```jldoctest
julia> spin = Spin([1.0, 2.0, 3.0], 1, 1000, 100, 3); spin.signal
1.0 + 2.0im
```
"""
struct Spin <: AbstractSpin
    M::Vector{Float64}
    M0::Float64
    T1::Float64
    T2::Float64
    Δf::Float64
    pos::Vector{Float64}

    # Default constructor with optional argument pos
    Spin(M::Vector{<:Real}, M0, T1, T2, Δf, pos = [0,0,0]) =
        new(M, M0, T1, T2, Δf, pos)

    # If magnetization vector is not specified then use equilibrium
    Spin(M0::Real, T1, T2, Δf, pos = [0,0,0]) =
        new([0,0,M0], M0, T1, T2, Δf, pos)
end

"""
    SpinMC([M,] M0, frac, T1, T2, Δf, τ[, pos]) <: AbstractSpin

Create an object that represents a single spin with multiple compartments.

# Properties
- `N::Integer = length(frac)`: Number of compartments
- `Meq::Vector{Float64} = vcat([[0, 0, frac[n] * M0] for n = 1:N]...)`:
    Equilibrium magnetization vector
- `M::Vector{Float64} = Meq`: Magnetization vector
    [M1x, M1y, M1z, M2x, M2y, M2z, ...]
- `M0::Real`: Equilibrium magnetization
- `frac::Vector{<:Real}`: Volume fraction of each compartment
- `T1::Vector{<:Real}`: Spin-lattice recovery time constants (ms)
- `T2::Vector{<:Real}`: Spin-spin recovery time constants (ms)
- `Δf::Vector{<:Real}`: Off-resonance frequencies (Hz)
- `τ::Vector{<:Real}`: Residence times (inverse exchange rates) (ms)
    [τ12, τ13, ..., τ1N, τ21, τ23, ..., τ2N, ...]
- `pos::Vector{<:Real} = [0, 0, 0]`: Spatial location [x, y, z] (cm)
- `A::Matrix{Float64} = ...`: Matrix of system dynamics; see slide 22 in
    https://web.stanford.edu/class/rad229/Notes/B1-Bloch-Simulations.pdf
- `signal::Complex{Float64}`: Signal produced by the spin

# Examples
```jldoctest
julia> M = [1.0, 2.0, 3.0, 0.2, 0.1, 1.0];

julia> frac = [0.8, 0.2];

julia> τ = [Inf, Inf];

julia> spin = SpinMC(M, 1, frac, [900, 400], [80, 20], [3, 13], τ); spin.signal
1.2 + 2.1im
```
"""
struct SpinMC <: AbstractSpin
    N::Int
    M::Vector{Float64} # [3N]
    Meq::Vector{Float64} # [3N]
    M0::Float64
    frac::Vector{Float64} # [N]
    T1::Vector{Float64} # [N]
    T2::Vector{Float64} # [N]
    Δf::Vector{Float64} # [N]
    τ::Vector{Float64} # [N*(N-1)]
    pos::Vector{Float64}
    A::Matrix{Float64} # [3N,3N]

    SpinMC(M::Vector{<:Real}, M0, frac, T1, T2, Δf, τ, pos = [0,0,0]) = begin
        N = length(frac)
        Meq = vcat([[0, 0, frac[n] * M0] for n = 1:N]...)
        r = zeros(N, N) # 1/ms
        itmp = 1
        for j = 1:N, i = 1:N
            if i != j
                r[i,j] = 1 / τ[itmp]
                itmp += 1
            end
        end
        A = zeros(3N, 3N)
        for j = 1:N, i = 1:N
            ii = 3i-2:3i
            jj = 3j-2:3j
            if i == j
                tmp = sum(r[:,i]) # 1/ms
                r1 = -1 / T1[i] - tmp # 1/ms
                r2 = -1 / T2[i] - tmp # 1/ms
                Δω = 2π * Δf[i] / 1000 # rad/ms
                A[ii,jj] = [r2 Δω 0; -Δω r2 0; 0 0 r1] # Left-handed rotation
            else
                A[ii,jj] = r[i,j] * Matrix(I,3,3)
            end
        end
        new(N, M, Meq, M0, frac, T1, T2, Δf, τ, pos, A)
    end

    # If magnetization vector is not specified then use equilibrium
    SpinMC(M0::Real, frac, T1, T2, Δf, τ, pos = [0,0,0]) = begin
        M = vcat([[0, 0, frac[n] * M0] for n = 1:length(frac)]...)
        SpinMC(M, M0, frac, T1, T2, Δf, τ, pos)
    end
end

# Override Base.getproperty to allow users to type spin.signal to compute the
# signal generated by the spin
Base.getproperty(spin::Spin, s::Symbol) = begin
    if s == :signal
        M = getfield(spin, :M)
        return M[1] + im * M[2]
    else
        return getfield(spin, s)
    end
end

Base.getproperty(spin::SpinMC, s::Symbol) = begin
    if s == :signal
        M = getfield(spin, :M)
        return sum(M[1:3:end]) + im * sum(M[2:3:end])
    else
        return getfield(spin, s)
    end
end

"""
    freeprecess(spin, t)

Simulate free-precession for the given spin.

# Arguments
- `spin::AbstractSpin`: Spin that is free-precessing
- `t::Real`: Duration of free-precession (ms)

# Return
- `A::Matrix`: Matrix that describes relaxation and precession
- `B::Vector`: Vector that describes recovery

# Examples
```jldoctest
julia> spin = Spin([1.0, 0.0, 0.0], 1, 1000, 100, 3.75)
Spin([1.0, 0.0, 0.0], 1.0, 1000.0, 100.0, 3.75, [0.0, 0.0, 0.0])

julia> (A, B) = freeprecess(spin, 100); A * spin.M + B
3-element Array{Float64,1}:
 -0.2601300475114444
 -0.2601300475114445
  0.09516258196404048
```
"""
freeprecess(spin::Spin, t::Real) =
    freeprecess(t, spin.M0, spin.T1, spin.T2, spin.Δf)

function freeprecess(spin::SpinMC, t::Real)

    E = exp(t * spin.A)
    B = (I - E) * spin.Meq
    return (E, B)

end

"""
    freeprecess(spin, t, grad)

Simulate free-precession for the given spin in the presence of a gradient.

# Arguments
- `spin::AbstractSpin`: Spin that is free-precessing
- `t::Real`: Duration of free-precession (ms)
- `grad::AbstractVector{<:Real}`: Gradient amplitudes [gx, gy, gz] (G/cm)

# Return
- `A::Matrix`: Matrix that describes relaxation and precession
- `B::Vector`: Vector that describes recovery

# Examples
```jldoctest
julia> spin = Spin([1.0, 0.0, 0.0], 1, 1000, 100, 0, [0, 0, 3.75])
Spin([1.0, 0.0, 0.0], 1.0, 1000.0, 100.0, 0.0, [0.0, 0.0, 3.75])

julia> (A, B) = freeprecess(spin, 100, [0, 0, 1/GAMBAR]); A * spin.M + B
3-element Array{Float64,1}:
 -0.2601300475114444
 -0.2601300475114445
  0.09516258196404048
```
"""
function freeprecess(spin::Spin, t::Real, grad::AbstractArray{<:Real,1})

    gradfreq = GAMBAR * sum(grad .* spin.pos) # Hz
    freeprecess(t, spin.M0, spin.T1, spin.T2, spin.Δf + gradfreq)

end

# See equation (6.9) in Gopal Nataraj's PhD thesis
function freeprecess(spin::SpinMC, t::Real, grad::AbstractArray{<:Real,1})

    gradfreq = GAMMA * sum(grad .* spin.pos) / 1000 # rad/ms
    ΔA = diagm(1 => repeat([gradfreq, 0, 0], spin.N), # Left-handed rotation
              -1 => repeat([-gradfreq, 0, 0], spin.N))[1:3spin.N,1:3spin.N]
    E = exp(t * (spin.A + ΔA))
    B = (I - E) * spin.Meq
    return (E, B)

end

"""
    freeprecess!(spin, ...)

Apply free-precession to the given spin.
"""
function freeprecess!(spin::AbstractSpin, args...)

    (A, B) = freeprecess(spin, args...)
    applydynamics!(spin, A, B)

end

"""
    excitation(spin, θ, α)

Simulate instantaneous excitation with flip angle `α` about an axis that makes
angle `θ` with the positive x-axis.

# Arguments
- `spin::AbstractSpin`: Spin to excite
- `θ::Real`: Orientation of the axis about which to excite (rad)
- `α::Real`: Flip angle (rad)

# Return
- `A::Matrix`: Matrix that describes the excitation
- `B::Vector = zeros(length(spin.M))`: Not used, but included because other
    methods of `excitation` return a nontrivial value here

# Examples
```jldoctest
julia> spin = Spin(1, 1000, 100, 3.75)
Spin([0.0, 0.0, 1.0], 1.0, 1000.0, 100.0, 3.75, [0.0, 0.0, 0.0])

julia> (A, _) = excitation(spin, π/4, π/2); A * spin.M
3-element Array{Float64,1}:
  0.7071067811865476
 -0.7071067811865475
  6.123233995736766e-17
```
"""
function excitation(spin::Spin, θ::Real, α::Real)

    A = rotatetheta(θ, α)
    B = zeros(length(spin.M))
    return (A, B)

end

function excitation(spin::SpinMC, θ::Real, α::Real)

    A = kron(Matrix(I,spin.N,spin.N), rotatetheta(θ, α))
    B = zeros(length(spin.M))
    return (A, B)

end

"""
    excitation(spin, rf, Δθ, grad, dt)

Simulate non-instantaneous excitation using the hard pulse approximation.

# Arguments
- `spin::AbstractSpin`: Spin to excite
- `rf::Vector{<:Number}`: RF waveform (G); its magnitude determines the flip
    angle and its phase determines the axis of rotation
- `Δθ::Real`: Additional RF phase (e.g., for RF spoiling) (rad)
- `grad::Union{Matrix{<:Real},Vector{<:Real}}`: Gradients to play during
    excitation (G/cm); should be a 3-vector if the gradients are constant during
    excitation, otherwise it should be a 3×(length(rf)) matrix
- `dt::Real`: Time step (ms)

# Return
- `A::Matrix`: Matrix that describes excitation and relaxation
- `B::Vector`: Vector that describes excitation and relaxation
"""
function excitation(spin::AbstractSpin, rf::AbstractArray{<:Number,1}, Δθ::Real,
                    grad::AbstractArray{<:Real,2}, dt::Real)

    T = length(rf)
    α = GAMMA * abs.(rf) * dt/1000 # Flip angle in rad
    θ = angle.(rf) .+ Δθ # RF phase in rad
    A = I
    B = zeros(length(spin.M))
    for t = 1:T
        (Af, Bf) = freeprecess(spin, dt/2, grad[:,t])
        (Ae, _) = excitation(spin, θ[t], α[t])
        A = Af * Ae * Af * A
        B = Af * (Ae * (Af * B + Bf)) + Bf
    end
    return (A, B)

end

# Excitation with constant gradient
function excitation(spin::AbstractSpin, rf::AbstractArray{<:Number,1}, Δθ::Real,
                    grad::AbstractArray{<:Real,1}, dt::Real)

    T = length(rf)
    α = GAMMA * abs.(rf) * dt/1000 # Flip angle in rad
    θ = angle.(rf) .+ Δθ # RF phase in rad
    A = I
    B = zeros(length(spin.M))
    (Af, Bf) = freeprecess(spin, dt/2, grad)
    for t = 1:T
        (Ae, _) = excitation(spin, θ[t], α[t])
        A = Af * Ae * Af * A
        B = Af * (Ae * (Af * B + Bf)) + Bf
    end
    return (A, B)

end

"""
    excitation!(spin, ...)

Apply excitation to the given spin.
"""
function excitation!(spin::AbstractSpin, θ::Real, α::Real)

    (A, _) = excitation(spin, θ, α)
    applydynamics!(spin, A)

end

# Use this function if using RF spoiling (because A and B need to be
# recalculated for each TR, so directly modifying the magnetization should be
# faster in this case)
function excitation!(spin::AbstractSpin, rf::AbstractArray{<:Number,1}, Δθ::Real,
                     grad::AbstractArray{<:Real,2}, dt::Real)

    T = length(rf)
    α = GAMMA * abs.(rf) * dt/1000 # Flip angle in rad
    θ = angle.(rf) .+ Δθ # RF phase in rad
    A = I
    B = zeros(length(spin.M))
    for t = 1:T
        (Af, Bf) = freeprecess(spin, dt/2, grad[:,t])
        (Ae, _) = excitation(spin, θ[t], α[t])
        applydynamics!(spin, Af, Bf)
        applydynamics!(spin, Ae)
        applydynamics!(spin, Af, Bf)
    end

end

function excitation!(spin::AbstractSpin, rf::AbstractArray{<:Number,1}, Δθ::Real,
                     grad::AbstractArray{<:Real,1}, dt::Real)

    T = length(rf)
    α = GAMMA * abs.(rf) * dt/1000 # Flip angle in rad
    θ = angle.(rf) .+ Δθ # RF phase in rad
    (Af, Bf) = freeprecess(spin, dt/2, grad)
    for t = 1:T
        (Ae, _) = excitation(spin, θ[t], α[t])
        applydynamics!(spin, Af, Bf)
        applydynamics!(spin, Ae)
        applydynamics!(spin, Af, Bf)
    end

end

"""
    spoil(spin)

Simulate ideal spoiling (i.e., setting the transverse component of the spin's
magnetization to 0).

# Arguments
- `spin::AbstractSpin`: Spin to spoil

# Return
- `S::Matrix`: Matrix that describes ideal spoiling

# Examples
```jldoctest
julia> spin = Spin([1, 0.4, 5], 1, 1000, 100, 0)
Spin([1.0, 0.4, 5.0], 1.0, 1000.0, 100.0, 0.0, [0.0, 0.0, 0.0])

julia> S = spoil(spin); S * spin.M
3-element Array{Float64,1}:
 0.0
 0.0
 5.0
```
"""
spoil(spin::Spin) = [0 0 0; 0 0 0; 0 0 1]
spoil(spin::SpinMC) = kron(Matrix(I,spin.N,spin.N), [0 0 0; 0 0 0; 0 0 1])

"""
    spoil!(spin)

Apply ideal spoiling to the given spin.
"""
function spoil!(spin::Spin)

    spin.M[1:2] .= 0
    return nothing

end

function spoil!(spin::SpinMC)

    spin.M[1:3:end] .= 0
    spin.M[2:3:end] .= 0
    return nothing

end

"""
    combine(D...)

Combine the matrices and vectors that describe the dynamics of a spin into one
matrix and one vector.

# Arguments
- `D::Tuple{<:AbstractArray{<:Real,2},<:AbstractVector{<:Real}}...`: List of
    pairs of matrices and vectors, i.e., ((A1, B1), (A2, B2), ...), where the
    A's are matrices and the B's are vectors

# Return
- `A::Matrix`: Matrix that describes the spin dynamics
- `B::Vector`: Vector that describes the spin dynamics

# Examples
```jldoctest
julia> spin = Spin(1, 1000, 100, 3.75)
Spin([0.0, 0.0, 1.0], 1.0, 1000.0, 100.0, 3.75, [0.0, 0.0, 0.0])

julia> D1 = excitation(spin, 0, π/2);

julia> D2 = freeprecess(spin, 100);

julia> (A, B) = combine(D1, D2); A * spin.M + B
3-element Array{Float64,1}:
 -0.2601300475114444
 -0.2601300475114445
  0.09516258196404054
```
"""
function combine(D::Tuple{<:AbstractArray{<:Real,2},<:AbstractArray{<:Real,1}}...)

  (A, B) = D[1]
  for i = 2:length(D)
    (Ai, Bi) = D[i]
    A = Ai * A
    B = Ai * B + Bi
  end
  return (A, B)

end

"""
    applydynamics!(spin, A[, B])

Apply dynamics to the given spin.

# Arguments
- `spin::AbstractSpin`: Spin to which to apply dynamics
- `A::Matrix`: Matrix with dynamics
- `B::Vector = zeros(length(spin.M))`: Vector with dynamics

# Examples
```jldoctest
julia> spin = Spin(1, 1000, 100, 3.75)
Spin([0.0, 0.0, 1.0], 1.0, 1000.0, 100.0, 3.75, [0.0, 0.0, 0.0])

julia> (A, _) = excitation(spin, 0, π/2); applydynamics!(spin, A)

julia> (A, B) = freeprecess(spin, 100); applydynamics!(spin, A, B)

julia> spin.M
3-element Array{Float64,1}:
 -0.2601300475114444
 -0.2601300475114445
  0.09516258196404054
```
"""
function applydynamics!(spin::AbstractSpin, A::AbstractArray{<:Real,2},
                        B::AbstractArray{<:Real,1})

  spin.M[:] = A * spin.M + B
  return nothing

end

function applydynamics!(spin::AbstractSpin, A::AbstractArray{<:Real,2})

  spin.M[:] = A * spin.M
  return nothing

end
