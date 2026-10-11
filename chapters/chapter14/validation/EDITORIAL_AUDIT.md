# Chapter 14 Editorial Audit

## Completed migration edits

- Added a publisher-style abstract.
- Retained the evidence-chain structure linking estimand, stochastic form, estimator/effects, diagnostics, covariance, and claim strength.
- Preserved and verified exact versus approximate percentage interpretations.
- Removed all EViews equation-view, freeze, spool, menu, and export instructions.
- Replaced the legacy application section with a script-first R/RStudio reporting workflow.
- Added explicit statistical-provenance guidance: CSV/LaTeX outputs are generated from verified data frames, not screenshots.
- Added `modelsummary` as the reporting layer while preventing it from silently determining cluster-reference inference.
- Replaced Applied EViews Exercises with Applied R/RStudio Exercises.
- Replaced EViews references with R, `plm`, and `modelsummary` documentation.
- Updated the bridge to Chapter 15 from an EViews workflow to a complete R/RStudio reproducibility pipeline.

## Reporting safeguards retained

- First-log-difference slopes are described as short-run growth elasticities.
- Finite percentage changes use the exact nonlinear transformation when appropriate.
- Non-significance is not described as proof of no effect.
- Cluster counts and covariance dimensions are reported.
- R-squared is not compared mechanically across different outcome transformations.
- Period-effect coefficients are omitted from the compact substantive table while their inclusion is clearly stated.
- Associational wording is used because the design does not establish causal identification.
