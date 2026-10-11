# Chapter 16 Editorial Audit

- Replaced EViews dynamic-LS/GMM menus and commands with R/RStudio workflows.
- Preserved the endogeneity/timing/moment-condition theory.
- Added explicit `ivreg` Anderson–Hsiao implementation and first-stage audit.
- Added `pgmm` difference/system distinction and `collapse=TRUE` discipline.
- Replaced software-specific instrument-count language with transparent combinatorial counts plus an actual-matrix audit function.
- Separated teaching GMM from the final case estimator.
- Preserved the teaching-period relabelling disclaimer.
- Replaced EViews software references with `plm` and `ivreg` documentation references.
- Avoided claiming a Windmeijer correction where the current primary `pgmm` help page does not state one explicitly.
