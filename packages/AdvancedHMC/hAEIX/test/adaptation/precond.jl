using Test, LinearAlgebra, Distributions, AdvancedHMC
using AdvancedHMC.Adaptation: WelfordVar, NaiveVar, WelfordCov, NaiveCov, add_sample!, get_var, get_cov, reset!
using DiffResults: GradientResult, value, gradient
using ForwardDiff: gradient!

# Check that the estimated variance is approximately correct.
@testset "Online v.s. naive v.s. true var/cov estimation" begin
    D = 10
    n_samples = 100_000

    var_welford = WelfordVar(D)
    var_naive = NaiveVar()
    var_estimators = [var_welford, var_naive]
    cov_welford = WelfordCov(D)
    cov_naive = NaiveCov()
    cov_estimators = [cov_welford, cov_naive]
    estimators = [var_estimators..., cov_estimators...]

    for dist in [MvNormal(zeros(D), ones(D)), Dirichlet(D, 1)]
        for _ = 1:n_samples
            s = rand(dist)
            for estimator in estimators
                add_sample!(estimator, s)
            end
        end

        @test get_var(var_welford) ≈ get_var(var_naive) atol=0.1D
        for estimator in var_estimators
            @test get_var(estimator) ≈ var(dist) atol=0.1D
        end

        @test get_cov(cov_welford) ≈ get_cov(cov_naive) atol=0.1D^2
        for estimator in cov_estimators
            @test get_cov(estimator) ≈ cov(dist) atol=0.1D^2
        end

        for estimator in estimators
            reset!(estimator)
        end
    end
end

@testset "Preconditioner constructors" begin
    θ = [0.0, 0.0, 0.0, 0.0]
    pc1 = Preconditioner(UnitEuclideanMetric) # default dim = 2
    pc2 = Preconditioner(DiagEuclideanMetric)
    pc3 = Preconditioner(DenseEuclideanMetric)

    # Var adaptor dimention should be increased to length(θ) from 2
    AdvancedHMC.adapt!(pc1, θ, 1.)
    AdvancedHMC.adapt!(pc2, θ, 1.)
    AdvancedHMC.adapt!(pc3, θ, 1.)
    @test AdvancedHMC.Adaptation.getM⁻¹(pc2) == ones(length(θ))
    @test AdvancedHMC.Adaptation.getM⁻¹(pc3) == LinearAlgebra.diagm(0 => ones(length(θ)))
end

@testset "Stan HMC adaptors" begin
    θ = [0.0, 0.0, 0.0, 0.0]

    adaptor1 = StanHMCAdaptor(
        1000,
        Preconditioner(UnitEuclideanMetric),
        NesterovDualAveraging(0.8, 0.5)
    )
    adaptor2 = StanHMCAdaptor(
        1000,
        Preconditioner(DiagEuclideanMetric),
        NesterovDualAveraging(0.8, 0.5)
    )
    adaptor3 = StanHMCAdaptor(
        1000,
        Preconditioner(DenseEuclideanMetric),
        NesterovDualAveraging(0.8, 0.5)
    )

    AdvancedHMC.adapt!(adaptor1, θ, 1.)
    AdvancedHMC.adapt!(adaptor2, θ, 1.)
    AdvancedHMC.adapt!(adaptor3, θ, 1.)
    @test AdvancedHMC.Adaptation.getM⁻¹(adaptor2) == ones(length(θ))
    @test AdvancedHMC.Adaptation.getM⁻¹(adaptor3) == LinearAlgebra.diagm(0 => ones(length(θ)))
end

@testset "Adapted mass v.s. true variance" begin

    function buildfuncs(target)
        ℓπ(θ) = logpdf(target, θ)

        function ∂ℓπ∂θ(θ)
            res = GradientResult(θ)
            gradient!(res, ℓπ, θ)
            return (value(res), gradient(res))
        end
        
        return ℓπ, ∂ℓπ∂θ
    end

    function runnuts(ℓπ, ∂ℓπ∂θ, metricT)
        n_samples = 2_000
        n_adapts = 1_000

        θ_init = randn(D)
        
        metric = metricT(length(θ_init))
        h = Hamiltonian(metric, ℓπ, ∂ℓπ∂θ)
        prop = NUTS(Leapfrog(find_good_eps(h, θ_init)))
        adaptor = StanHMCAdaptor(
            n_adapts, 
            Preconditioner(metric), 
            NesterovDualAveraging(0.8, prop.integrator.ϵ)
        )
        samples, stats = sample(h, prop, θ_init, n_samples, adaptor, n_adapts; verbose=false)
        return (samples=samples, stats=stats, adaptor=adaptor)
    end

    D = 10

    n_tests = 5

    @testset "DiagEuclideanMetric" begin
        for _ in 1:n_tests
            # Random variance
            σ = ones(D) + abs.(randn(D))
        
            # Diagonal Gaussian
            target = MvNormal(zeros(D), σ)
            ℓπ, ∂ℓπ∂θ = buildfuncs(target)
            
            res = runnuts(ℓπ, ∂ℓπ∂θ, DiagEuclideanMetric)
            @test res.adaptor.pc.var ≈ σ .^ 2 rtol=0.2
            
            res = runnuts(ℓπ, ∂ℓπ∂θ, DenseEuclideanMetric)
            @test res.adaptor.pc.covar ≈ diagm(0 => σ.^2) rtol=0.25
        end
    end

    @testset "DenseEuclideanMetric" begin
        for _ in 1:n_tests
            # Random covariance
            m = randn(D, D)
            Σ = m' * m

            # Correlated Gaussian
            target = MvNormal(zeros(D), Σ)
            ℓπ, ∂ℓπ∂θ = buildfuncs(target)
            
            res = runnuts(ℓπ, ∂ℓπ∂θ, DiagEuclideanMetric)
            @test res.adaptor.pc.var ≈ diag(Σ) rtol=0.2
            
            res = runnuts(ℓπ, ∂ℓπ∂θ, DenseEuclideanMetric)
            @test res.adaptor.pc.covar ≈ Σ rtol=0.25
        end
    end

end