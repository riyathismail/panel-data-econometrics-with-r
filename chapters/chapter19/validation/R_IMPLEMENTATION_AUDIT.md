# Chapter 19 R Implementation Audit

## Native mappings

- Heterogeneous panel Granger test: `plm::pgrangertest()`.
- Individual test details: the returned `indgranger` component.
- Fixed-effects stationary PVAR cross-check: `panelvar::pvarfeols()`.
- PVAR stability cross-check: `panelvar::stability()`.
- Guarded PVAR GMM sensitivity: `panelvar::pvargmm()` supports FD/FOD, lag limits, collapsing, PCA instruments, and optional system instruments.

## Deliberate transparent implementations

- Period-clustered CR1 inference is computed explicitly equation by equation.
- The synchronous block bootstrap uses frozen time-resample indices to eliminate cross-language RNG drift.
- Generalized IRFs are calculated directly from `A1` and `Sigma` because the documented direct `girf()` method is attached to `pvargmm`, while the case benchmark is fixed-effects least squares.
- Generalized FEVD is computed explicitly because `panelvar::fevd_orthogonal()` is an orthogonal, ordering-dependent decomposition, whereas the case reports normalized generalized shares.

## Econometric limitations retained

The fixed-effects PVAR contains lagged dependent variables and therefore remains subject to finite-T dynamic-panel bias. With N=10, a large-instrument PVAR-GMM specification is not treated as automatically superior. Reduced-form innovations and generalized responses are not structural causal shocks.

## Runtime status

R is unavailable in the migration runtime. Package-native execution, `sessionInfo()`, and final `renv.lock` remain pending. Independent numerical validation and PDF QA are completed outside R.
