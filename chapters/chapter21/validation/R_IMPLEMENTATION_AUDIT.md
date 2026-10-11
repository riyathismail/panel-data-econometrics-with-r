# Chapter 21 R Implementation Audit

## Mapping

- Known common panel break: `lm()` with post-period slope interactions.
- Cluster covariance: explicit CR1 formula, `sandwich::vcovCL()` as cross-check.
- Unknown common break: custom candidate-date loop with 2012--2021 trimming.
- Search-adjusted inference: supplied period-level Rademacher wild-cluster bootstrap that repeats the full date search.
- Rolling slopes: explicit seven-period `lm()` loop.
- Single-axis structural-change tools: `strucchange::Fstats()`, `sctest()`, and `breakpoints()` documented only for genuine ordered time-series applications.

## Important non-equivalence

`strucchange::breakpoints()` is not treated as a panel-aware Bai--Perron estimator on 190 firm-major stacked rows. A common teaching-period break must respect the nineteen-period time dimension.

## Runtime

R is not installed in the migration container. The script has not been falsely certified as executed; independent numerical reconstruction supplies the release benchmarks and hard assertions.
