# Chapter 9 R Implementation Audit

## Native estimator mapping

- LSDV: `stats::lm(... + factor(firm))`
- Manual within estimator: explicit firm demeaning plus an intercept-free `lm()`
- Native panel FE: `plm::plm(..., model = "within", effect = "individual")`
- Time FE: `effect = "time"`
- Two-way FE: `effect = "twoways"`
- Normalized effects: `plm::fixef(type = "dmean")` and `plm::within_intercept()`
- Pooled-vs-FE test: `plm::pFtest()`
- Conditional period/firm tests: equivalent nested LSDV models using explicit RSS/F calculations
- Cluster covariance: `sandwich::vcovCL()` on the equivalent LSDV regression

## Core verification design

Chapter 9 deliberately estimates one-way FE three separate ways. The slope vector is not accepted unless LSDV, manual demeaning, and `plm` within estimates agree to numerical tolerance. This guards against accidental inclusion of a constant in the manual within regression, incorrect grouping, or a malformed panel index.

## Normalization

Fixed-effect intercept decompositions are normalization dependent. The publisher benchmark uses a sum-to-zero normalization. The common intercept and firm deviations are cross-checked between the equivalent LSDV model and `fixef(..., type = "dmean")` / `within_intercept()`.

## Effect tests

`pFtest()` is used for pooled versus one-way FE. For two-way specifications, nested LSDV models are retained as the transparent benchmark so that each null's conditioning set is explicit: periods given firms, firms given periods, and both dimensions jointly.

## Covariance

The one-way FE slope estimates are unchanged under conventional, firm-clustered, period-clustered, and two-way-clustered covariance estimators. Because the number of firms is only ten, cluster-based inference is treated as sensitivity evidence rather than an asymptotic guarantee.

## Runtime status

The current migration container does not contain R. Source construction and independent numerical validation are complete, but live execution of `R/chapter09.R`, `sessionInfo()`, and the final `renv.lock` remain pending.
