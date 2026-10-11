# Chapter 8 Editorial Audit

Completed changes:

- Added a chapter abstract.
- Preserved the full derivation of the FD transformation and the exact list of terms removed/not removed.
- Replaced all EViews menus, commands, workfile instructions, and covariance option names with R/RStudio code.
- Standardized R variable names as `dlinvest`, `dlvalue`, and `dlcapital` for raw first log differences.
- Added a direct manual-FD versus `plm(model = "fd")` cross-check.
- Clarified that `plm` retains an FD intercept by default.
- Replaced EViews covariance language with HC1/CR1 and `sandwich` terminology.
- Recast the period-effects and post-FD firm-dummy tests as explicit nested models in R.
- Preserved the distinction between FD and within FE and their exact equivalence when `T = 2`.
- Preserved the measurement-error amplification warning.
- Replaced the EViews software reference with `plm`, `sandwich`, and R references.
- Retained the warning that teaching-period labels 2006-2025 are not contemporary observation dates.
