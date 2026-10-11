# Chapter 24 R Implementation Audit

## Architecture

The legacy EViews workfile/program/spool workflow has been replaced with an RStudio Project containing reusable functions, a `_targets.R` dependency graph, `testthat` release checks, SHA-256 data provenance, explicit cluster covariance code, publication-table exports, session capture, and a post-run `renv` snapshot step.

## Naming

Raw first log differences are `dlinvest`, `dlvalue`, and `dlcapital`. Percentage-scaled versions use `_pct`. This preserves the R-edition convention established in Chapter 5 and eliminates factor-of-100 ambiguity.

## Statistical defaults

CR1 finite-sample corrections and reference degrees of freedom are coded explicitly. `modelsummary` receives already-verified reporting values and is not allowed to choose the inferential convention.

## Runtime status

R is unavailable in the migration container. Source construction, numerical reconstruction, document compilation, and PDF QA are complete. Live `tar_make()`, `testthat`, `sessionInfo()`, and final `renv.lock` generation remain pending.
