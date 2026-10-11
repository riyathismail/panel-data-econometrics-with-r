# Chapter 10 Editorial Audit

- Added a publisher-style chapter abstract.
- Preserved the error-components covariance derivation, ICC, GLS, quasi-demeaning, shrinkage, time-invariant-regressor discussion, mixed/two-way effects, and robust-inference cautions.
- Replaced the complete EViews implementation section with an R/RStudio workflow.
- Added manual quasi-demeaning as a transparent numerical cross-check against `plm` random effects.
- Replaced legacy EViews exercises with R exercises.
- Replaced EViews documentation references with R/`plm`/`sandwich` references.
- Explicitly separated the LM question (is the random-component variance zero?) from the Hausman/CRE question (is the component orthogonal to the regressors?).
- Retained the logged-level stationarity/cointegration qualification.
- Documented the lack of a direct Wansbeek--Kapteyn `random.method` in `plm`.
