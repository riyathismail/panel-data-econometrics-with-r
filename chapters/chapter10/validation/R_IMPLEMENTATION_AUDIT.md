# Chapter 10 R Implementation Audit

## Native mapping

- Random effects: `plm::plm(..., model = "random", effect = "individual")`.
- Swamy--Arora variance components: `random.method = "swar"` plus a fully explicit balanced-panel reconstruction.
- Variance components and quasi-demeaning parameter: `plm::ercomp()`.
- Pooled-vs-random-component LM tests: `plm::plmtest(..., type = "bp")` and `type = "honda"`.
- Predicted random effects: `plm::ranef()` plus an independent shrinkage-formula reconstruction.
- Robust covariance sensitivity: `sandwich::vcovHC()` and one-/two-way `sandwich::vcovCL()` applied to the manually quasi-demeaned regression.

## Method-equivalence rule

Current `plm` documentation lists Swamy--Arora (`swar`), Wallace--Hussain (`walhus`), Amemiya (`amemiya`), and Nerlove (`nerlove`) as random-effects component estimators. It does not expose a `random.method` named Wansbeek--Kapteyn. The R edition therefore documents the missing direct mapping instead of inventing an equivalent.

## Core validation

The manual balanced-panel reconstruction independently reproduces the published variance components, conditional ICC, theta, RE coefficient vector, conventional standard errors, LM statistics, shrinkage factor, predicted firm effects, covariance-sensitivity table, and the first-difference zero-variance boundary case.

## Runtime status

The current migration runtime does not contain an R interpreter. The `plm` cross-checks are encoded as executable assertions but remain a live-production release gate.
