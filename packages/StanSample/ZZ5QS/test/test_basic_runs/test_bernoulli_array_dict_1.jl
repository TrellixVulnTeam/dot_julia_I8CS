######### CmdStan sample example  ###########

using StanSample

bernoulli_model = "
data { 
  int<lower=1> N; 
  int<lower=0,upper=1> y[N];
} 
parameters {
  real<lower=0,upper=1> theta;
} 
model {
  theta ~ beta(1,1);
  y ~ bernoulli(theta);
}
";

bernoulli_data = [
  Dict("N" => 10, "y" => [0, 1, 0, 1, 0, 0, 0, 0, 0, 1]),
  Dict("N" => 10, "y" => [0, 1, 0, 0, 1, 0, 0, 0, 0, 1]),
  Dict("N" => 10, "y" => [0, 1, 0, 1, 0, 0, 0, 0, 1, 0]),
  Dict("N" => 10, "y" => [0, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
]

# Keep tmpdir identical across multiple runs to prevent re-compilation
stanmodel = SampleModel(
  "bernoulli", bernoulli_model; tmpdir = tmpdir,
  method =  StanSample.Sample(adapt=StanSample.Adapt(delta=0.85)))

stan_sample(stanmodel, data=bernoulli_data, diagnostics=true)
# Convert to an MCMCChains.Chains object
chns = read_samples(stanmodel)
# Fetch the same output in the `sdf` ChainDataFrame
sdf = read_summary(stanmodel)
  