# Chapter 22 R Package Notes

- `fixest`: two-way fixed-effects estimation and Sun--Abraham `sunab()` templates.
- `sandwich`: one- and multi-way clustered covariance cross-checks.
- `clubSandwich`: CR2 covariance and Satterthwaite few-cluster coefficient testing.
- `did`: Callaway--Sant'Anna group-time ATT estimation and aggregation for genuine staggered adoption.
- `readr`, `dplyr`, `tidyr`, `ggplot2`: deterministic data construction and publication outputs.

The main common-adoption benchmark remains calculable with base `lm()` plus explicit covariance helpers. This keeps the published numbers auditable independently of high-level package defaults.
