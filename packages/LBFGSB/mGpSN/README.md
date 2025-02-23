# LBFGSB

[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
[![Build Status](https://travis-ci.org/Gnimuc/LBFGSB.jl.svg?branch=master)](https://travis-ci.org/Gnimuc/LBFGSB.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/xlub93nifbjnit7a/branch/master?svg=true)](https://ci.appveyor.com/project/Gnimuc/lbfgsb-jl/branch/master)
[![codecov](https://codecov.io/gh/Gnimuc/LBFGSB.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Gnimuc/LBFGSB.jl)

This is a Julia wrapper for [L-BFGS-B Nonlinear Optimization Code](http://users.iems.northwestern.edu/%7Enocedal/lbfgsb.html).
It will download and use pre-compiled binaries from [L-BFGS-B-Builder](https://github.com/Gnimuc/L-BFGS-B-Builder).

## Installation
```julia
pkg> add LBFGSB
```

## Usage
```julia
using LBFGSB

# define a function that maps a vector to a scalar
# let's define a multidimensional Rosenbrock function(https://en.wikipedia.org/wiki/Rosenbrock_function): 
function f(x)
    y = 0.25 * (x[1] - 1)^2
    for i = 2:length(x)
        y += (x[i] - x[i-1]^2)^2
    end
    4y
end

# and its gradient function that maps a vector to a vector
function g(x)
    n = length(x)
    z = zeros(n)
    t₁ = x[2] - x[1]^2
    z[1] = 2 * (x[1] - 1) - 1.6e1 * x[1] * t₁
    for i = 2:n-1
        t₂ = t₁
        t₁ = x[i+1] - x[i]^2
        z[i] = 8 * t₂ - 1.6e1 * x[i] * t₁
    end
    z[n] = 8 * t₁
    z
end

# define a function that returns both f(scalar) and its gradient(vector)
func(x) = f(x), g(x)

# the first argument is the dimension of the largest problem to be solved
# the second argument is the maximum number of limited memory corrections
optimizer = L_BFGS_B(1024, 17)
n = 25  # the dimension of the problem
x = fill(Cdouble(3e0), n)  # the initial guess
# set up bounds
bounds = zeros(3, n)
for i = 1:n
    bounds[1,i] = 2  # represents the type of bounds imposed on the variables:
                     #  0->unbounded, 1->only lower bound, 2-> both lower and upper bounds, 3->only upper bound
    bounds[2,i] = isodd(i) ? 1e0 : -1e2  #  the lower bound on x, of length n.
    bounds[3,i] = 1e2  #  the upper bound on x, of length n.
end
# call the optimizer
# - m: the maximum number of variable metric corrections used to define the limited memory matrix
# - factr: the iteration will stop when (f^k - f^{k+1})/max{|f^k|,|f^{k+1}|,1} <= factr*epsmch,
#     where epsmch is the machine precision, which is automatically generated by the code. Typical values for factr:
#     1e12 for low accuracy, 1e7 for moderate accuracy, 1e1 for extremely high accuracy
# - pgtol: the iteration will stop when max{|proj g_i | i = 1, ..., n} <= pgtol where pg_i is the ith component of the projected gradient
# - iprint: controls the frequency of output. iprint < 0 means no output:
#     iprint = 0 print only one line at the last iteration
#     0 < iprint < 99 print also f and |proj g| every iprint iterations
#     iprint = 99 print details of every iteration except n-vectors
#     iprint = 100 print also the changes of active set and final x
#     iprint > 100 print details of every iteration including x and g
# - maxfun: the maximum number of function evaluations
# - maxiter: the maximum number of iterations
julia> fout, xout = optimizer(func, x, bounds, m=5, factr=1e7, pgtol=1e-5, iprint=-1, maxfun=15000, maxiter=15000)
(1.0834900834300615e-9, [1.0, 1.0, 1.0, 1.00001, 1.00001, 1.00001, 1.00001, 1.00001, 1.00002, 1.00004  …  1.0026, 1.00521, 1.01045, 1.02101, 1.04246, 1.08672, 1.18097, 1.39469, 1.94516, 3.78366])

# if your func needs extra arguments, a closure can be used to do the trick:
# optimizer(λ->func(λ, extra_args...), x, bounds, m=5, factr=1e7, pgtol=1e-5, iprint=-1, maxfun=15000, maxiter=15000)
```
The original examples/drivers in the L-BFGS-B library are translated in the `test` folder directly using low-level `setulb`.

## License
Note that, only the wrapper code in this repo is licensed under MIT, those downloaded
binaries are released under BSD-3-Clause license.
