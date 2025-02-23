Knet v1.2.4 Release Notes
=========================

* Fixed permutedims speed using CuArrays.


Knet v1.2.3 Release Notes
=========================
bb024b4 2019-07-25

* Tutorial notebook fixes.
* Saved KnetArrays now load as regular Arrays on cpu, not reshaped/reinterpreted.


Knet v1.2.2 Release Notes
=========================
caba6b7b 2019-05-25

* Highorder gradient bug fixes for linear and mlp models.
* Removed compat section from Project.toml.
* GPU support for gamma functions (@xukai92).
* Fixed Knet.randn! to work with odd length arrays.
* Fixed issues with gpu library error messages.
* RNN checks input sizes and types more strictly.
* Windows 10 installation tested and documentation updated.


Knet v1.2.1 Release Notes
=========================
e81011ec 2019-02-18

* Serialization bug fix.
* Fixed eltype, size etc. for Minimize, Converge etc.
* Transpose and matmul now work with 1-D KnetArrays.
* Added intro learning notebook.
* RNN: Ignore trailing ones when comparing sizes.
* Julia 1.2 compat fixes.


Knet v1.2.0 Release Notes
=========================
3e5c7e0 2019-01-21

* New training interface based on iterators.
* Progressbar and converge utilities.
* RNN unboxes hidden states in backward pass making `value(h)` unnecessary on GPU.
* `rnnparam` and `rnnparams` no longer take a `w` argument.
* RNN applies dropout to input like other layers.
* `mat` takes a `dims` keyword argument that makes it useful for both RNNs and CNNs.
* Dropout automatically figures out and does nothing outside of `@diff` context.
* Fixed inplace assignment for Params and KnetArrays.
* Julia 1.0 fixes for `goldensection`.
* Improved default parameters for all optimizers tested on MLP, CNN, RNN.
* All notebooks and documentation updated.
* New iterator and quickstart notebooks.
* Updated to Documenter 0.21.


Knet v1.1.2 Release Notes
=========================
20d91106 2019-01-04

* Support for broadcasting user defined functions.
* Added batch matrix multiplication. (@ozanarkancan)
* Improved serialization and JLD file I/O. (@ekinakyurek)
* Added tests and docs for new RNN interface.
* Added julia/base demo to tutorial/08.charlm
* Renamed broadcast.jl -> binary.jl and broadcast_ops -> binary_ops.


Knet v1.1.1 Release Notes
=========================
6f27c1d5 2018-09-30

* General performance improvements.
* New GPU memory manager. (with @ekinakyurek)
* New logging system using Base.CoreLogging.
* New cuda macros and profiling system using TimerOutputs.
* Tutorial available on Colab. (with @jekbradbury)
* Added cpucopy, gpucopy serialization. (with @ekinakyurek)
* Added softmax, logsoftmax, logistic loss and binary-cross-entropy. (@CarloLucibello, @ekinakyurek)
* Added elu and selu. (with @CarloLucibello)
* Speed up matmul gradient avoiding transpose.
* Defined permutedims(::KnetMatrix)
* Fixed scripts under Knet/prof, added new results.


Knet v1.1.0 Release Notes
=========================
df820c53 2018-09-12

The new suggested way to define models/layers is as [callable objects](https://docs.julialang.org/en/v1/manual/methods/#Function-like-objects-1).

    struct Linear; w; b; end
    (m::Linear)(x) = m.w * x .+ m.b

This way a model acts as a (predict) function as well as a collection of parameters:

    m = Linear(randn(10,784), zeros(10))
    y = m(x)             # gives the prediction
    for p in params(m)   # iterates over parameters

For training the parameters should be marked as AutoGrad.Param objects:

    m = Linear(Param(randn(10,784)), Param(zeros(10)))
    y = m(x)             # returns the same y value as above (test mode)
    y = @diff m(x)       # gives an object with prediction as well as grad info
    value(y)  		 # gives the prediction value
    gradient(y, m.w)     # gives the gradient of value(y) wrt m.w

This interface is not mandatory, everything should be backwardly compatible and old Knet
code should continue to work.  However the new interface should allow people to easily
define their layer/model collections and thus address Issues #144, #147, #341.

I am working on a minimal set of utilities for the new interface on the dy/1.1 branch:
* A new `train!` function that works with the new interface.
* `param` and `param0` make declaring parameters easier.
* `params` recursively finds all Params in a given object.
* Additional loss and update methods can handle callable objects.
* Better RNN interface: m=LSTM(input,hidden); m(x) => y
* Possibly other layers/models defined for MLP and CNNs.

I am not sure about the last item because I'd rather keep the Knet interface minimal and let
people work on their own model/layer collections.  I am updating Knet/examples/dl-tutorial
notebooks as I work on the new interface if you want to see examples.


Knet v1.0.1 Release Notes
=========================
43421754 2018-08-31

* Improved gpu diagnostics.
* build.jl no longer depends on Knet.
* AutoGrad 1.0.1 compatibility fixes.
* Fixed some examples and notebooks.
* Fixed Documenter, avoiding python dependency.
* JLD2 FileIO interface (@ekinakyurek).


Knet v1.0.0 Release Notes
=========================
249540a 2018-08-20

* Julia 1.0 compatibility fixes.


Knet v0.9.2 Release Notes
=========================
4aa5f92 2018-08-14

* Fixed rnnparam cudnn-7.1.4 compat issue.
* Updated dl-tutorial.
* updated REQUIRE to upper bound Julia version.


Knet v0.9.1 Release Notes
=========================
26562f5 2018-05-28

Compatibility
-------------
* Library discovery now done using CUDAapi.
* GPU direct peer access support (@cangumeli).
* Removed gpu-architecture compiler flags from build.jl to support machines with heterogenous gpu types.
* Added JuliaBox compatibility to Jupyter notebooks.

General
-------
* Fixed default `dropout` behavior which was not applying dropout to input to obey the pdrop argument.
* Added support for `mean(f::Function,x::KnetArray)`.
* Added `vcat` support for scalar arguments.
* Fixed `batchnorm` cpu backward pass (@CarloLucibello)

Documentation and Examples
--------------------------
* Grid image display support for notebooks (@ilkerkesen).
* Convolutional VAE example (@CarloLucibello).
* Reinforcement learning examples (@ozanarkancan).
* dl-tutorial collects updated notebooks @denizyuret uses in class.


Knet v0.9.0 Release Notes
=========================
48ca185 2017-12-25

Compatibility
-------------
* Windows GPU support implemented.
* MacOS GPU support improved: nvml only used when available.
* CUDA up to v"9.1" and cuDNN up to v"7.0.5" are tested.
* Pre-0.6 Julia versions no longer supported.

General
-------
* `rnninit` and `rnnforw` implement cudnn RNNs (with @cangumeli).
* `conv4` performance significantly improved using cudnnFind.
* `batchnorm` implemented using CUDNN (@cangumeli).
* `logp` performance significantly improved using cudnnSoftmaxForward.
* `DBGFLAGS` and `PROFILING` constants defined in Knet.jl.
* `optimizers` creates optimization structs for the whole model.
* `dropout` now detects training mode automatically.
* `nll` returns negative log likelihood given score matrix and answer index vector.
* `accuracy` returns ratio of correct answers given score matrix and answer index vector.
* `minibatch(x,y,b)` returns a batch iterator.
* `knetgc` is now exported to cudaFree garbage collected pointers.
* `randn!`, `mean(a,dims)`, `reshape` with `Colon` is now supported by KnetArray (@CarloLucibello).
* Using CUDAapi and CUDAdrv in build.jl if installed.
* Got rid of the Combinatorics dependency in test.
* `curandInit` called at initialization to prevent memory fill before first dropout.
* `deconv4` bug fixed (@ilkerkesen).

Documentation and Examples
--------------------------
* New benchmarking notebooks under examples/DeepLearningFrameworks (with @kirnap, @ilkarman).
* Knet/data now has download utilities: cifar.jl, fashion-mnist.jl, gutenberg.jl, housing.jl, imagenet.jl, imdb.jl, mikolovptb.jl, mnist.jl, treebank.jl, wikiner.jl
* All examples updated to use the new RNNs and replaced/supported with IJulia notebooks.
* New variational-autoencoder example (@CarloLucibello).
* DyNet benchmark examples added (@ilkerkesen).
* Deep Convolutional Generative Adversarial Networks example added (@ilkerkesen).


Knet v0.8.5 Release Notes
=========================
8ea130e 2017-10-21

General
-------
* Fixed memory leak with certain broadcast kernels (@ilkerkesen).
* Fixed dropout efficiency bug introduced in 0.8.4.
* Added conditional support for SpecialFunctions.
* Added Nesterov optimizer (@CarloLucibello).
* Removed Compat dependency.
* Proper handling of concat KnetArrays of incompatible eltypes (#175).
* Fixed dotted function handling in Julia5 (#173).

Documentation and Examples
--------------------------
* Fixed julia6 compat problem in examples/mnist.jl.
* charlm.jl can now save generated text (@DoguD).
* Added fashion-mnist.jl example (@quaertym).
* Added missing `MNIST.loaddata()` to tutorial.jl.
* Fixed julia4 compat problem in examples/vgg.jl.


Knet v0.8.4 Release Notes
=========================
2a2cba3 on 2017-09-09

* Julia 0.6 compatibility fixes.
* Fixed compiler flags in Makefile for compatibility.
* charlm unicode character problem fixed.


Knet v0.8.3 Release Notes
=========================
48d4924 on 2017-05-18

General
-------
* KnetArray support for general broadcasting operations (@EnisBerk).
* KnetArray support for general reduction operations (@ilkerkesen).
* KnetArray support for permutedims up to 5D (@ekyurdakul).
* KnetArray indexing support for Int, Colon, UnitRange, StepRange, CartesianIndex, Array{Int}, Array{Bool}, Array{CartesianIndex}. Most combinations work for 2-D.  N-D indexing incomplete.  See `@doc KnetArray` for details.
* KnetArray support for multi-argument `hcat` and `vcat`.
* KnetArray support for saving to and loading from JLD files.
* Implemented `hyperband` and `goldensection` hyperparameter optimization algorithms.
* Added per weight-array gradient clip to `update!`.
* Fixed `update!` issues with `grad::Void` and other mismatched `w,grad` types.
* Fixed `update!` issues with `grad::Dict` missing keys.
* Added `setseed` to do `srand` in both cpu and gpu.
* Added `dropout(a,p)` as a Knet primitive.
* Implemented `mean(::KnetArray,r)`.

Testing and Benchmarking
------------------------
* Benchmarks added under prof/ for reduction, broadcast, concat, conv operations; rnnlm, s2s models.

Documentation and Examples
--------------------------
* RNN chapter and IJulia notebook added.
* Updated the CNN chapter.
* Solutions to installation problems documented.
* Fixed vgg and resnet demos to use the new version of Images.jl and to work on CPU-only machines. Fixed batch normalization bug in resnet. (@ilkerkesen)
* Fixed charlm demo to use indexing operations, Adam, and dropout.
* Added rnnlm demo.


Knet v0.8.2 Release Notes
=========================
8f77f85 on Feb 23, 2017

General
-------
* update! now supports iterators and dictionaries of weight arrays.
* CPU convolution and pooling operations implemented based on CPP kernels from Mocha.jl.
* gradcheck automatically handles non-scalar functions, stays quiet by default, returns true/false. Moved to AutoGrad.
* KnetArray now supports isempty, (.!=), (==), isapprox, copy!, scale!, deepcopy, more math functions (exp,log etc.), and KnetArray{T}(dims) constructors.
* KnetArray supports transpose and permutedims for 2-D and 3-D (@ekyurdakul).
* Gradients for KnetArray to Array conversion (@ereday).
* gaussian, xavier, bilinear initializers in distributions.jl (@ekyurdakul).
* New deconvolution and unpool operations in cuda44.jl (@ekyurdakul).
* Default conv4 padding changed back to 0. Knet.padsize(w) still available to compute size-preserving padding.
* GPU garbage collection does not print '.', '+' unless user modifies gcinfo macro.
* It is now an error to try to create a KnetArray when the active device is not a gpu.
* Fixed bug in (scalar .> KnetArray) operation in cuda01.jl.
* Updated AutoGrad requirement to v0.0.6.

Documentation and Testing
-------------------------
* Comprehensive unit-testing implemented.
* All documentation moved to Markdown using Documenter.jl.
* Documentation for examples and a reference section added.
* Unsupported ops documented in KnetArray doc.

Examples
--------
* Batch Normalization/ResNet example (resnet.jl) added. (@ilkerkesen)
* vgg.jl now supports D and E models (@ilkerkesen).
* hyperband.jl hyperparameter optimization example added.
* softmax.ipynb IJulia notebook about underfitting, overfitting, regularization and dropout.
* optimizers.jl padding bug fixed.


Knet v0.8.1 Release Notes
=========================
c9556d4 on Dec 7, 2016

General
-------

* update! defined supporting SGD, Momentum, Adagrad, Adadelta, Rmsprop, Adam (@ozanarkancan).
* Knet.dir(path) returns path relative to Knet root.
* axpy!, rand!, vec defined for KnetArray.
* relu, sigm, invx defined for scalars.
* Numerically stable sigm and logsumexp implemented.
* GPU discovery and selection made more robust using nvml.
* GPU memory management improved.
* Default conv4 padding changed to (w-1)/2 which preserves input size.
* Older versions of libcudnn now supported.

Documentation and Testing
-------------------------

* profmlp deprecates profile_kn for speed tests.
* Documentation updated with Knet8 examples.
* README updated with RNN example, benchmarks, architecture.

Examples
--------

* VGG image recognition demo added.
* Examples Pkg.add required packages automatically.
* housing example supports train/test ratio option.
* examples/optimizers.jl has usage examples of new update! functions (@ozanarkancan).
