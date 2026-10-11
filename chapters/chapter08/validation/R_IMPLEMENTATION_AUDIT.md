# Chapter 8 R Implementation Audit

## Native estimator mapping

- Manual first-log differences: grouped `dplyr::lag()` construction followed by `stats::lm()`.
- Panel first-difference estimator: `plm::plm(..., model = "fd")` applied to logged levels.
- Robust covariance: `sandwich::vcovHC()` and `sandwich::vcovCL()` plus explicit HC1/CR1 benchmark formulas.
- Period effects after differencing: `stats::lm(... + factor(year))` with nested `anova()` test.
- Firm-specific growth intercepts after differencing: `stats::lm(... + factor(firm))` with nested `anova()` test.
- Arithmetic first differences: grouped differences in original units followed by `lm()`.

## Important implementation detail

Current `plm` documentation states that `model = "fd"` implements the first-difference estimator and retains an intercept by default. In a levels interpretation, that intercept corresponds to allowing a deterministic linear trend. `nobs()` reports the 190 observations actually used even though the original panel model frame contains 200 level observations.

## Statistical safeguards

1. All differences are computed within firm boundaries.
2. The R script asserts equality between manual FD coefficients and `plm(model = "fd")` coefficients.
3. Period effects are tested after differencing because common time shocks survive as changes in period effects.
4. Firm dummies after FD are not mislabelled as the original fixed effects.
5. Theoretical transformed-error correlation of `-0.5` is presented conditionally on i.i.d. level innovations, not as a mandatory empirical residual target.
6. Cluster corrections and reference degrees of freedom are recorded explicitly because only 10 firm clusters are available.

## Runtime status

The migration runtime used to create this package does not contain R. Source construction and independent cross-engine numerical validation are complete, but the live R execution gate remains pending.
