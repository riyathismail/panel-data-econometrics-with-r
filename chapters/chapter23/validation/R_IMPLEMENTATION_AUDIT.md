# Chapter 23 R Implementation Audit

## Binary-response mapping

- Transparent dummy fixed-effects logit/probit: `stats::glm(..., family = binomial(link = ...))`.
- High-dimensional unconditional FE GLM cross-check: `fixest::feglm(... | firm)`.
- Conditional fixed-effects logit: `survival::clogit(... + strata(firm), method = "exact")`.
- Average marginal effects: explicit formulas plus `marginaleffects::avg_slopes()` cross-check.
- One-/two-way clustered sandwich: explicit CR1 score-sandwich formulas plus `sandwich::vcovCL()` cross-check.
- Random-intercept binary sensitivity: `lme4::glmer(... + (1 | firm), family = binomial())`.
- Correlated random effects: random-intercept logit plus firm means of time-varying covariates.

## Important nonlinear-FE distinction

`fixest::feglm()` with a firm fixed effect is an unconditional fixed-effects GLM. It is not the same estimator as conditional fixed-effects logit. The latter conditions on each firm's sufficient statistic and is mapped to `survival::clogit()`.

## Separation

Teaching label 2022 has ten successes and zero failures. A fully saturated period-dummy ordinary logit therefore contains a perfectly predictive period indicator. The production workflow diagnoses this outcome pattern before attempting such a model and uses a parsimonious teaching-period trend for the benchmark logit/probit.

## Count-model mapping

The Grunfeld data contain no defensible native count outcome. The count section is therefore conceptual. R templates use:

- `fixest::fepois()` for high-dimensional Poisson fixed-effects QMLE;
- `fixest::fenegbin()` as a negative-binomial sensitivity whose heterogeneity assumptions must be interpreted carefully;
- `glmmTMB::glmmTMB()` for random-effects Poisson/negative-binomial models and richer count distributions.

No artificial count variable is manufactured from investment levels.

## Runtime status

`Rscript` is not installed in the migration container. R source/API mapping, independent numerical validation, and PDF integration are complete. Clean-session R execution, `sessionInfo()`, and final `renv.lock` remain pending.
