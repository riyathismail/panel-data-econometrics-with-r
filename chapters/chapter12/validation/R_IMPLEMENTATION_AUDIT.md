# Chapter 12 R Implementation Audit

## Native R mapping

- Target panel models: `plm::plm()` plus equivalent `lm()` LSDV forms.
- Breusch-Pagan/Koenker heteroskedasticity test: `lmtest::bptest()`.
- White heteroskedasticity test: `skedastic::white()` on effect-residualized substantive designs.
- First-difference Wooldridge logic: `plm::pwfdtest()` plus an explicit residual-AR reconstruction for the exact period-adjusted benchmark.
- Complementary FE serial-correlation tests: `plm::pwartest()` and `plm::pbgtest()`.
- Cross-sectional dependence: `plm::pcdtest()` plus direct pairwise residual-correlation reconstruction.
- RESET: `lmtest::resettest()` for the conventional F test and an explicit two-way CR1 auxiliary-regression Wald test.
- Influence: base-R `cooks.distance()`, `rstudent()`, `dffits()`, `covratio()`, `hatvalues()`, `dfbetas()`, and `influence.measures()` on equivalent LSDV models.

## Methodological safeguards

1. Diagnostics are run on the same transformed samples as the target equations.
2. The `rho=-0.5` null for first-differenced residuals is kept distinct from the `rho=0` null for the differenced disturbance itself.
3. Signed residual correlation after period effects is not interpreted mechanically as a negative economic spillover.
4. VIF is calculated after removing the effects relevant to the estimator.
5. The groupwise variance LR is labelled a normal-theory teaching diagnostic, not an exact finite-sample panel test.
6. Cook's-distance thresholds are screening rules; observations are not deleted mechanically.
7. Robust covariance changes inference but cannot repair endogeneity or functional-form misspecification.

## Runtime status

The migration container has no R interpreter. The R source is therefore not falsely marked as executed. The independent numerical benchmark and PDF build are complete; live `R/chapter12.R` execution and `renv.lock` capture remain pending.
