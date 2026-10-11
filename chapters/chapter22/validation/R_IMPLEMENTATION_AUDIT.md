# Chapter 22 R Implementation Audit

## Core common-adoption estimator

The synthetic outcome is reconstructed from the untouched Grunfeld CSV as `dlinvest_sim = dlinvest + 0.08 * treatment`. Treatment is active only for firms 1--5 from teaching label 2018 onward. The chapter never rewrites the original `invest`, `value`, or `capital` levels.

The primary common-adoption estimator is an explicit least-squares two-way fixed-effects model using `lm()` with firm and period factors. `fixest::feols()` is included as a high-dimensional fixed-effects cross-check. The treatment coefficient must agree across the two parameterizations.

## Inference

- CR1 firm clustering is the primary conventional covariance because treatment assignment occurs at firm level.
- Period and two-way CR1 covariance estimates are reported as sensitivity analyses.
- The finite-sample CR1 correction is written explicitly rather than delegated to an unnamed package default.
- `sandwich::vcovCL()` provides package cross-checks.
- `clubSandwich::coef_test(..., vcov="CR2", test="Satterthwaite")` is a live-R few-cluster sensitivity; it is not silently substituted for the published CR1 benchmark.

## Few-cluster reference calculations

The treatment assignment in the teaching exercise was deterministic, not randomized. Accordingly, the complete five-of-ten reassignment distribution is labelled a hypothetical complete-random-assignment reference rather than design-exact randomization inference.

The restricted firm-level wild-cluster-t calculation imposes the null through the restricted model and exhaustively enumerates all 2^10 firm-level Rademacher sign patterns. No Monte Carlo random number generator is used.

## Event study

Teaching label 2017 (`k=-1`) is omitted. The four pre-treatment bins are tested jointly using the explicit firm-CR1 covariance and an F(4,9) reference. Non-rejection is described only as compatibility evidence, not proof of parallel trends.

## Staggered adoption

The synthetic case has one common treatment date, so it is not passed to staggered-treatment estimators. The chapter instead provides separate templates for:

- `did::att_gt()` and `did::aggte()` for group-time ATTs and their aggregations;
- `fixest::sunab()` for Sun--Abraham interaction-weighted event-study estimation.

These templates require real first-treatment timing metadata and a defensible comparison group.

## Runtime status

R is not installed in the migration container. All reader-facing numerical benchmarks were independently reconstructed from the authoritative CSV, and hard assertions were placed in `R/chapter22.R`. Live package cross-checks, CR2 output, `sessionInfo()`, and final `renv.lock` remain pending.
