# Chapter 17 R Implementation Audit

## Method mapping

- Panel Pedroni: `pco::pedroni99m()`; documented multivariate Pedroni (1999) implementation, balanced T x N x M array, null of no cointegration.
- Kao: **no false mapping**. A generic residual ADF is not called Kao because Kao requires specific generated-residual and nuisance-parameter corrections.
- Individual Johansen: `urca::ca.jo()`; reports trace/eigen statistics and critical values for each firm.
- Firm-specific Engle–Granger comparison: `aTSA::coint.test()` in the live R run; the independent benchmark also records the legacy MacKinnon-response-surface replication for reconciliation.
- FMOLS/DOLS time-series diagnostics: `cointReg` is available, but it is not represented as a drop-in panel-FMOLS aggregator.
- Published DOLS case benchmark: explicit `lm()` with firm effects, period effects, and one lead/lag of each regressor first difference.
- Published ECM: explicit `lm()` with lagged DOLS equilibrium error, current first differences, and period effects.
- Cluster inference: explicit CR1 period-cluster covariance using G/(G-1) * (n-1)/(n-k), with t_(G-1) reference.

## Cross-sectional-dependence qualification

The first-log-difference CD statistics are large for all three variables. The Pedroni result is therefore a first-generation sensitivity rather than dependence-robust evidence. The manuscript does not claim a second-generation Westerlund result that was not implemented and validated.

## Runtime status

The current migration container has no R interpreter. Package-native Pedroni, aTSA Engle–Granger, Johansen, optional `cointReg`, `sessionInfo()`, and real `renv.lock` outputs remain pending live R execution. The DOLS/ECM and legacy transparent numerical benchmarks were independently reconstructed from the raw CSV.
