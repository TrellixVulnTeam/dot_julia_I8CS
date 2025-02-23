using CovarianceMatrices
using Test
using CSV
using LinearAlgebra
############################################################
## HAC
############################################################

X = randn(100, 5);

@time vcov(X, TruncatedKernel(2.))
@time vcov(X, BartlettKernel(2.))
@time vcov(X, ParzenKernel(2.))
@time vcov(X, QuadraticSpectralKernel(2.))
@time vcov(X, TruncatedKernel())
@time vcov(X, BartlettKernel())
@time vcov(X, ParzenKernel())
@time vcov(X, QuadraticSpectralKernel())

############################################################
## HC
############################################################

# A Gamma example, from McCullagh & Nelder (1989, pp. 300-2)
clotting = DataFrame(
    u    = log.([5,10,15,20,30,40,60,80,100]),
    lot1 = [118,58,42,35,27,25,21,19,18],
    lot2 = [69,35,26,21,18,16,13,12,12],
    w    = 9.0*[1/8, 1/9, 1/25, 1/6, 1/14, 1/25, 1/15, 1/13, 0.3022039]
)

## Unweighted OLS though GLM interface
OLS = fit(GeneralizedLinearModel, @formula(lot1~u),clotting, Normal(), IdentityLink())
mf = ModelFrame(@formula(lot1~u),clotting)
X = ModelMatrix(mf).m
y = clotting[:lot1]
GL  = fit(GeneralizedLinearModel, X,y, Normal(), IdentityLink())
LM  = lm(X,y)

S0 = vcov(OLS, HC0())
S1 = vcov(OLS, HC1())
S2 = vcov(OLS, HC2())
S3 = vcov(OLS, HC3())
S4 = vcov(OLS, HC4())
S4m = vcov(OLS, HC4m())
S5 = vcov(OLS, HC5())

St0 = [720.6213 -190.0645; -190.0645 51.16333]
St1 = [926.5131 -244.3687; -244.3687 65.78143]
St2 = [1300.896 -343.3307; -343.3307 91.99719]
St3 = [2384.504 -628.975 ; -628.975 167.7898]
St4 = [2538.746 -667.9597; -667.9597 177.2631]
St4m= [3221.095 -849.648 ; -849.648 226.1705]
St5 = St4

@test abs.(maximum(S0 .- St0)) < 1e-04
@test abs.(maximum(S1 .- St1)) < 1e-04
@test abs.(maximum(S2 .- St2)) < 1e-04
@test abs.(maximum(S3 .- St3)) < 1e-04
@test abs.(maximum(S4 .- St4)) < 1e-03
@test abs.(maximum(S4m .- St4m)) < 1e-03
@test abs.(maximum(S5 .- St5)) < 1e-03

S0 = vcov(GL, HC0())
S1 = vcov(GL, HC1())
S2 = vcov(GL, HC2())
S3 = vcov(GL, HC3())
S4 = vcov(GL, HC4())
S4m = vcov(GL, HC4m())
S5 = vcov(GL, HC5())

@test St0 ≈ S0 atol = 1e-4
@test St1 ≈ S1 atol = 1e-4
@test St2 ≈ S2 atol = 1e-3
@test St3 ≈ S3 atol = 1e-4
@test St4 ≈ S4 atol = 1e-3
@test St4m ≈ S4m atol = 1e-3
@test St5 ≈ S5 atol = 1e-3

M0 = CovarianceMatrices.meat(OLS, HC0())
M1 = CovarianceMatrices.meat(OLS, HC1())
M2 = CovarianceMatrices.meat(OLS, HC2())
M3 = CovarianceMatrices.meat(OLS, HC3())
M4 = CovarianceMatrices.meat(OLS, HC4())
M4m = CovarianceMatrices.meat(OLS, HC4m())
M5 = CovarianceMatrices.meat(OLS, HC5())

Mt0 = [206.6103 518.7871; 518.7871 1531.173]
Mt1 = [265.6418 667.012;  667.012 1968.651]
Mt2 = [323.993 763.0424;  763.0424 2149.767]
Mt3 = [531.478 1172.751;  1172.751 3122.79]
Mt4 = [531.1047 1110.762; 1110.762 2783.269]
Mt4m= [669.8647 1412.227; 1412.227 3603.247]
Mt5 = Mt4

@test abs.(maximum(M0 .- Mt0)) < 1e-04
@test abs.(maximum(M1 .- Mt1)) < 1e-04
@test abs.(maximum(M2 .- Mt2)) < 1e-04
@test abs.(maximum(M3 .- Mt3)) < 1e-03
@test abs.(maximum(M4 .- Mt4)) < 1e-03
@test abs.(maximum(M4m .- Mt4m)) < 1e-03
@test abs.(maximum(M5 .- Mt5)) < 1e-03

## Unweighted
OLS = glm(@formula(lot1~u),clotting, Normal(), IdentityLink())
S0 = vcov(OLS, HC0())
S1 = vcov(OLS, HC1())
S2 = vcov(OLS, HC2())
S3 = vcov(OLS, HC3())
S4 = vcov(OLS, HC4())

## Weighted OLS though GLM interface
wOLS = fit(GeneralizedLinearModel, @formula(lot1~u), clotting, Normal(),
           IdentityLink(), wts = Vector{Float64}(clotting[:w]))

wts = Vector{Float64}(clotting[:w])
X = [fill(1,size(clotting[:u])) clotting[:u]]
y = clotting[:lot1]
wLM = lm(X, y)
wGL = fit(GeneralizedLinearModel, X, y, Normal(),
            IdentityLink(), wts = wts)

residuals_raw = y-X*coef(wGL)
residuals_wts = sqrt.(wts).*(y-X*coef(wGL))

@test CovarianceMatrices.modelresiduals(wOLS) == CovarianceMatrices.modelresiduals(wGL)
@test CovarianceMatrices.modelresiduals(wOLS) == residuals_wts
@test CovarianceMatrices.modelresiduals(wGL)  == residuals_wts
@test CovarianceMatrices.modelweights(wGL)    == CovarianceMatrices.modelweights(wOLS)
@test CovarianceMatrices.rawresiduals(wGL)    == CovarianceMatrices.rawresiduals(wOLS)

wXX   = (wts.*X)'*X
wXu   = X.*(residuals_raw.*wts)
wXuuX = wXu'*wXu

@test CovarianceMatrices.fullyweightedmodelmatrix(wOLS) == X.*wts
@test CovarianceMatrices.fullyweightedmodelmatrix(wOLS).*CovarianceMatrices.rawresiduals(wOLS) ≈ wXu
@test CovarianceMatrices.meat(wOLS, HC0()) ≈  wXuuX./(sum(wts))

@test CovarianceMatrices.XX(wOLS) ≈ wXX
@test CovarianceMatrices.invXX(wOLS) ≈ inv(wXX)

S0 = vcov(wOLS, HC0())
S1 = vcov(wOLS, HC1())
S2 = vcov(wOLS, HC2())
S3 = vcov(wOLS, HC3())
S4 = vcov(wOLS, HC4())
S4m= vcov(wOLS, HC4m())
S5 = vcov(wOLS, HC5())

St0 = [717.7362 -178.4043; -178.4043 45.82273]
St1 = [922.8037 -229.3769; -229.3769 58.91494]
St2 = [1412.94 -361.33; -361.33 95.91252]
St3 = [2869.531 -756.2976; -756.2976 208.2344]
St4 = [3969.913 -1131.358; -1131.358 342.2859]
St4m= [4111.626 -1103.174; -1103.174   310.194]
St5 = St4

@test abs.(maximum(S0 .- St0)) < 1e-04
@test abs.(maximum(S1 .- St1)) < 1e-04
@test abs.(maximum(S2 .- St2)) < 1e-03
@test abs.(maximum(S3 .- St3)) < 1e-03
@test abs.(maximum(S4 .- St4)) < 1e-03
@test abs.(maximum(S4m .- St4m)) < 1e-03
@test abs.(maximum(S5 .- St5)) < 1e-03

## Unweighted GLM - Gamma
GAMMA = glm(@formula(lot1~u), clotting, Gamma(),InverseLink())

S0 = vcov(GAMMA, HC0())
S1 = vcov(GAMMA, HC1())
S2 = vcov(GAMMA, HC2())
S3 = vcov(GAMMA, HC3())
S4 = vcov(GAMMA, HC4())
S4m = vcov(GAMMA, HC4m())
S5 = vcov(GAMMA, HC5())

St0 = [4.504287921232951e-07 -1.700020601541489e-07;
       -1.700020601541490e-07  8.203697048568913e-08]

St1 = [5.791227327299548e-07 -2.185740773410504e-07;
       -2.185740773410510e-07  1.054761049101728e-07]

St2 = [3.192633083111232e-06 -9.942484630848573e-07;
       -9.942484630848578e-07  3.329973305723091e-07]

St3 = [2.982697811926944e-05 -8.948137019946751e-06;
       -8.948137019946738e-06  2.712024459305714e-06]

St4 = [0.002840158946368653 -0.0008474436578800430;
       -0.000847443657880045  0.0002528819761961959]

St4m= [8.49306e-05 -2.43618e-05; -2.43618e-05  7.04210e-06]

St5 = St4

@test abs.(maximum(S0 .- St0)) < 1e-06
@test abs.(maximum(S1 .- St1)) < 1e-06
@test abs.(maximum(S2 .- St2)) < 1e-06
@test abs.(maximum(S3 .- St3)) < 1e-06
@test abs.(maximum(S4 .- St4)) < 1e-06
@test abs.(maximum(S4m .- St4m)) < 1e-05
@test abs.(maximum(S5 .- St5)) < 1e-05

## Weighted Gamma

GAMMA = glm(@formula(lot1~u), clotting, Gamma(),InverseLink(), wts = convert(Array, clotting[:w]))

S0 = vcov(GAMMA, HC0())
S1 = vcov(GAMMA, HC1())
S2 = vcov(GAMMA, HC2())
S3 = vcov(GAMMA, HC3())
S4 = vcov(GAMMA, HC4())
S4m = vcov(GAMMA, HC4m())
S5 = vcov(GAMMA, HC5())

St0 = [4.015104e-07 -1.615094e-07;
       -1.615094e-07  8.378363e-08]

St1 = [5.162277e-07 -2.076549e-07;
       -2.076549e-07  1.077218e-07]

St2 = [2.720127e-06 -8.490977e-07;
       -8.490977e-07  2.963563e-07]

St3 = [2.638128e-05 -7.639883e-06;
       -7.639883e-06  2.259590e-06]

St4 = [0.0029025754 -0.0008275858;
       -0.0008275858  0.0002360053]

St4m = [8.493064e-05 -2.436180e-05; -2.436180e-05  7.042101e-06]

St5 = St4


@test abs.(maximum(S0 .- St0)) < 1e-06
@test abs.(maximum(S1 .- St1)) < 1e-06
@test abs.(maximum(S2 .- St2)) < 1e-06
@test abs.(maximum(S3 .- St3)) < 1e-06
@test abs.(maximum(S4 .- St4)) < 1e-06
@test abs.(maximum(S4m .- St4m)) < 1e-05
@test abs.(maximum(S5 .- St5)) < 1e-05


### Cluster basic interface

## Construct Fake ols data

## srand(1)

## df = DataFrame( Y = randn(500),
##                X1 = randn(500),
##                X2 = randn(500),
##                X3 = randn(500),
##                X4 = randn(500),
##                X5 = randn(500),
##                w  = rand(500),
##                cl = repmat(collect(1:25), 20))

df = CSV.read("wols_test.csv")

OLS = fit(GeneralizedLinearModel, @formula(Y~X1+X2+X3+X4+X5), df,
          Normal(), IdentityLink())

S0 = vcov(OLS, HC0())
S1 = vcov(OLS, HC1())
S2 = vcov(OLS, HC2())
S3 = vcov(OLS, HC3())
S4 = vcov(OLS, HC4())
S5 = vcov(OLS, HC5())

cl = convert(Array, df[:cl])
S0 = stderror(OLS, CRHC0(cl))
S1 = stderror(OLS, CRHC1(cl))
S2 = stderror(OLS, CRHC2(cl))
S3 = stderror(OLS, CRHC3(cl))


## STATA
St1 = [.0374668, .0497666, .0472636, .0437952, .0513613, .0435369]

@test maximum(abs.(S0 .- St1)) < 1e-02
@test maximum(abs.(S1 .- St1)) < 1e-04
@test maximum(abs.(S2 .- St1)) < 1e-02
@test maximum(abs.(S3 .- St1)) < 1e-02


wOLS = fit(GeneralizedLinearModel, @formula(Y~X1+X2+X3+X4+X5), df,
          Normal(), IdentityLink(), wts = convert(Array{Float64}, df[:w]))

S0 = stderror(wOLS, CRHC0(cl))
S1 = stderror(wOLS, CRHC1(cl))
S2 = stderror(wOLS, CRHC2(cl))
S3 = stderror(wOLS, CRHC3(cl))

St1 = [0.042839848169137905,0.04927285387211425,
       0.05229519531359171,0.041417170723876025,
       0.04748115282615204,0.04758615959662984]

@test maximum(abs.(S1 .- St1)) < 1e-10

############################################################
## Test different interfaces
############################################################

# y = randn(100);
# x = randn(100, 5);

# lm1 = lm(x, y)
# @test stderror(lm1, HC0())≈[0.0941998, 0.0946132, 0.0961678, 0.0960445, 0.101651] atol=1e-06
# @test diag(vcov(lm1, HC0()))≈[0.0941998, 0.0946132, 0.0961678, 0.0960445, 0.101651].^2 atol=1e-06

############################################################
## HAC
############################################################

include("ols_hac.jl")
