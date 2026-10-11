# Chapter 16 R Implementation Audit

## Current function mapping

- Anderson–Hsiao / 2SLS: `ivreg::ivreg()`.
- Difference GMM: `plm::pgmm(..., transformation="d")`.
- System GMM: `plm::pgmm(..., transformation="ld")`.
- Restricted/collapsed GMM instruments: `lag(..., 2:3)` plus `collapse=TRUE`.
- Arellano–Bond serial-correlation diagnostics: `plm::mtest(order=1/2)`.
- Hansen–Sargan overidentification test: `plm::sargan()`.

## Important non-equivalences/corrections

1. Two-step weighting and system GMM are distinct choices.
2. Current `pgmm` documentation supports `collapse=TRUE`; the chapter uses it in the teaching code.
3. The current `pgmm` help page describes `summary(..., robust=TRUE)` as robust inference but does not itself label that option as a Windmeijer correction. The manuscript therefore does not make an unsupported software-specific Windmeijer claim.
4. Current `plm` documentation does not document a dedicated difference-in-Hansen helper; the chapter does not invent one.
5. GMM is deliberately optional because N=10 is poorly matched to conventional dynamic-GMM asymptotics and potential instrument counts.

## Runtime status

R is absent from the migration container. Dynamic OLS, FE, cluster covariance, IV, first-stage, and instrument-count benchmarks were independently reconstructed; `pgmm` execution remains pending.
