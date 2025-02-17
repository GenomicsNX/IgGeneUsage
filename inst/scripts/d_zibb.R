set.seed(seed = 12345)

# Stan generative model
sim_stan <- "
functions {
  int zibb_rng(int trials, real a, real b, real zi) {
    if (bernoulli_rng(zi) == 1) {
      return (0);
    } else {
      return (beta_binomial_rng(trials, a, b));
    }
  }
}

data {
  int<lower=0> N_rep;
  int<lower=0> N_gene;
  int<lower=0> N [N_rep*2];
  vector [N_gene] as;
  vector [N_gene] bs;
  real sigma;
  real phi;
  real z;
}

generated quantities {
  real a_sim;
  real b_sim;
  int ysim [N_gene, N_rep*2];
  real a;
  real b;
  
  for(s in 1:N_rep) {
    for(g in 1:N_gene) {
      a_sim = normal_rng(as[g], sigma);
      b_sim = normal_rng(bs[g], sigma);
      a = inv_logit(a_sim + b_sim*1) * phi;
      b = phi - a;
      ysim[g,s] = zibb_rng(N[s], a, b, z);
    }
  }
  for(s in 1:N_rep) {
    for(g in 1:N_gene) {
      a_sim = normal_rng(as[g], sigma);
      b_sim = normal_rng(bs[g], sigma);
      a = inv_logit(a_sim + b_sim*-1) * phi;
      b = phi - a;
      ysim[g,N_rep+s] = zibb_rng(N[N_rep+s], a, b, z);
    }
  }
}
" 

# compile model
m <- rstan::stan_model(model_code = sim_stan)

# generate data based on following fixed parameters
N_rep <- 5
N_gene <- 20
Y_max <- 500
as <- -rexp(n = N_gene, rate = 0.2)
bs <- sample(x = c(-1, 1), size = length(as), replace = T)*as/20
bs[which.max(as)] <- 2
d <- list(N_rep = N_rep, 
          N_gene = N_gene, 
          N = rep(x = Y_max, times = N_rep*2),
          as = as,
          bs = bs,
          sigma = 0.25,
          phi = 20,
          z = 0.05)

# simulate
sim <- rstan::sampling(object = m,
                       data = d, 
                       iter = 1, 
                       chains = 1, 
                       algorithm="Fixed_param")

# extract simulation and convert into data frame which can 
# be used as input of IgGeneUsage
ysim <- rstan::extract(object = sim, par = "ysim")$ysim
ysim <- ysim[1, ,]

ysim_df <- reshape2::melt(ysim)
colnames(ysim_df) <- c("gene_name", "sample_id", "gene_usage_count")
ysim_df$condition <- ifelse(test = ysim_df$sample_id<=N_rep, 
                            yes = "C1",
                            no = "C2")
ysim_df <- ysim_df[, c("sample_id", "condition", "gene_name", "gene_usage_count")]
ysim_df$sample_id <- paste0("S", as.character(ysim_df$sample_id))
ysim_df$gene_name <- paste0("G", as.character(ysim_df$gene_name))
d_zibb <- ysim_df

# save
save(d_zibb, file = "data/d_zibb.RData")

