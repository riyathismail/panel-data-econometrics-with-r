# Chapter 18 R Implementation Audit

- Panel-safe lags/differences are constructed inside `group_by(firm)`.
- Forecast origins are explicit teaching-period blocks, never random stacked rows.
- Forecasts are generated before held-out outcomes are used for scoring.
- `stats::predict.lm()` supplies point predictions and conventional prediction intervals.
- `plm::predict()` is discussed for FE/RE prediction, including the distinction between known indexes and weighted-mean filling for unseen effects.
- The core rolling loop is explicit rather than hidden behind resampling machinery; `rsample` may be used as an optional period-nested workflow.
- Smearing factors are recalculated at every origin using only training residuals.
- Growth MAPE is deliberately not reported because signed/near-zero growth makes it unstable or undefined.
- Level MAPE is reported because gross investment is positive.
- Conventional `predict.lm` intervals are not labelled cluster-robust panel intervals.
- Live R execution is pending because R is unavailable in the migration runtime.
