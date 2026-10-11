# Chapter 13 R Implementation Audit

## Primary computational source

`R/chapter13.R`

## Native R mapping

- HC/Arellano panel covariance: `plm::vcovHC()` and `sandwich::vcovHC()`.
- Firm/time clustering: `plm::vcovHC(..., cluster="group"/"time")` and `sandwich::vcovCL()`.
- Double clustering: `plm::vcovDC()` and multi-way `sandwich::vcovCL()`.
- Beck-Katz PCSE: `plm::vcovBK()` with unrestricted or diagonal cross-sectional covariance.
- Driscoll-Kraay: `plm::vcovSCC(..., maxlag=2)`.
- Few-cluster sensitivity: `clubSandwich::vcovCR(type="CR2")` and `coef_test(test="Satterthwaite")`.
- FGLS: `plm::pggls()` is discussed as an estimator-changing method, not treated as a covariance-only correction.

## Publication benchmark design

The publication tables do not depend on unnamed package defaults. `R/chapter13.R` defines HC1, CR1, two-way CR1, balanced-panel PCSE, and Bartlett-bandwidth-2 Driscoll-Kraay formulas explicitly. This preserves the chapter's finite-sample conventions across future package versions.

Package-native covariance matrices are exported separately as implementation cross-checks. Small differences are acceptable if caused by documented transformed-design or degrees-of-freedom conventions; they must not be overwritten to force numerical identity.

## Key assertions

- 200 logged-level observations and 190 first-log-difference observations.
- Level two-way FE slopes: 0.328554135 and 0.076795861.
- Period-adjusted growth slopes: 0.495709424 and -0.085692611.
- Expanded design sizes: K=31 and K=21.
- All 16 reported standard errors in each covariance-sensitivity table are checked against independent benchmarks.
- Cluster confidence intervals for the growth equation are regenerated from the stated t references.

## Runtime status

The migration environment does not contain `Rscript`. Source construction and independent numerical verification are complete; live package execution, CR2 results, `sessionInfo()`, and final `renv.lock` remain pending.
