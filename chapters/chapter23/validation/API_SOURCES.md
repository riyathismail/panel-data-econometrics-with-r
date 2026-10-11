# Current R API sources checked for Chapter 23

- `survival::clogit()` — conditional logistic likelihood with strata.
- `fixest::feglm()` — fixed-effects generalized linear models; `fepois()`/`fenegbin()` count estimators.
- `sandwich::vcovCL()` — clustered sandwich covariance.
- `marginaleffects::avg_slopes()` — average marginal effects / slopes.
- `lme4::glmer()` — generalized linear mixed models with random effects.
- `glmmTMB::glmmTMB()` — flexible generalized linear mixed models including Poisson and negative-binomial families.

The release manuscript distinguishes package implementation from econometric identification; a package function is not treated as evidence that its maintained assumptions are appropriate for the case.
