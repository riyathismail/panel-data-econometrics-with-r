# Chapter 12 Editorial Audit

- Added a publisher-style chapter abstract.
- Replaced the complete EViews diagnostic application with R/RStudio code.
- Preserved the two specification-specific diagnostic targets: logged-level two-way FE and period-adjusted first-log-difference model.
- Added explicit package-native mappings for `pwfdtest`, `pwartest`, `pbgtest`, `pcdtest`, `bptest`, `resettest`, White testing, and influence diagnostics.
- Clarified that `pwfdtest(h0="fe")` and `pwfdtest(h0="fd")` test different hypotheses.
- Retained and strengthened warnings against using Durbin-Watson as the sole panel serial-correlation diagnostic.
- Kept the period-label disclosure and original Grunfeld measurement units.
- Replaced the applied EViews exercises with R/RStudio exercises.
- Removed all reader-facing EViews/workfile/menu commands and the EViews documentation reference.
- Kept diagnosis conceptually separate from the Chapter 13 covariance remedy.
