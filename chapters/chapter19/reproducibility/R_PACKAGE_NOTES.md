# R Package Notes — Chapter 19

- `plm`: `pdata.frame()` and `pgrangertest()` for Dumitrescu–Hurlin panel Granger testing.
- `panelvar`: `pvarfeols()` fixed-effects PVAR cross-check, `stability()`, and guarded PVAR-GMM tooling.
- `sandwich`: covariance cross-checks where useful; the publication benchmark uses an explicit CR1 helper.
- `lmtest`: supporting regression-test infrastructure.
- `readr`, `dplyr`, `tidyr`: deterministic import, lags, and table reshaping.
- `ggplot2`: vector publication figures.

The package-native PVAR output is not allowed to silently replace the explicit benchmark. In particular, period-clustered standard errors, generalized IRFs, and generalized FEVDs are calculated from transparent formulas in `R/chapter19.R` because their interpretation is central to the chapter.
