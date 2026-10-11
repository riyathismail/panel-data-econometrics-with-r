# Chapter 21 R Package Notes

- `sandwich::vcovCL()` provides cluster-robust covariance cross-checks; the published CR1 benchmark is coded explicitly.
- `strucchange::Fstats()` and `breakpoints()` are appropriate for a genuine one-observation-per-time-axis linear regression. They are not panel-aware break-date commands for firm-major stacked data.
- The unknown-date panel test is therefore implemented through explicit period interactions and a period-level wild-cluster bootstrap.
- `bootstrap_weights_seed2107.csv` freezes the 4,999 x 19 Rademacher randomization design used for the published Monte Carlo benchmark.
