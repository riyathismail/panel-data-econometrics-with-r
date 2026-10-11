# R Package Notes — Chapter 23

- `stats::glm()` supplies the transparent dummy-variable logit/probit benchmark.
- `fixest::feglm()` cross-checks high-dimensional fixed-effects GLM slopes; `fepois()`/`fenegbin()` are count-panel templates.
- `survival::clogit()` implements conditional logistic likelihood via firm strata.
- `sandwich::vcovCL()` cross-checks one- and two-way clustered sandwich covariance.
- `marginaleffects::avg_slopes()` cross-checks AMEs.
- `lme4::glmer()` illustrates random-intercept and correlated-random-effects binary models.
- `glmmTMB` is included for richer count/random-effects templates.

The published coefficient/covariance benchmark is defined by explicit formulas and hard assertions in `R/chapter23.R`; package-native output is a cross-check rather than an unnamed numerical default.
