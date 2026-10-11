# Chapter 11 R Implementation Audit

## Native estimator-selection mapping

- Pooled vs fixed effects: `plm::pFtest(fe, pool)`.
- Pooled vs random effects: `plm::plmtest(pool, effect = "individual", type = "bp")`.
- Conventional FE vs RE: `plm::phtest(fe, re)`.
- Robust auxiliary Hausman sensitivity: formula-interface `phtest(..., method = "aux", vcov = ...)`.
- Period-adjusted correlated-effects check: transparent Mundlak auxiliary regression with period dummies and explicit two-way CR1 covariance.

## Independent numerical assertions

`R/chapter11.R` contains hard assertions for:

- `F(9,188) = 52.284645443` for pooled vs one-way FE;
- `LM = 754.636423561` for the individual Breusch-Pagan random-component test;
- `chi-square(2) = 7.715151276` for the conventional one-way Hausman comparison;
- the FE-RE coefficient-difference vector and covariance-difference matrix;
- `F(19,169) = 7.535040288` for period effects conditional on firm FE;
- `chi-square(2) = 32.202709311` for the period-adjusted Mundlak mean restrictions under explicit two-way CR1 covariance;
- `F(9,178) = 0.194074151` for additional firm intercepts after first differencing;
- `F(18,169) = 4.844946975` for period effects in the first-log-difference model.

## Robust-covariance convention

The published Mundlak benchmark is based on a written CR1 formula rather than an unnamed package default. One-way CR1 uses `G/(G-1) * (n-1)/(n-k)`. Two-way clustering adds the firm and period covariance components and subtracts the firm-period intersection component. `sandwich::vcovCL()` is retained as a package cross-check.

## Runtime status

The migration container does not contain an R interpreter. Therefore live `plm`, `sandwich`, and `sessionInfo()` execution remains PENDING. The source construction, independent cross-engine numerical benchmark, and PDF integration are complete.
