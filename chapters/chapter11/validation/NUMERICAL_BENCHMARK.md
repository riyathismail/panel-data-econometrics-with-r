# Chapter 11 Numerical Benchmark

Independent benchmark recomputed directly from the authoritative Grunfeld teaching CSV. The final R release gate requires execution of `R/chapter11.R` in the locked R environment.

## Data integrity

- 200 level observations = 10 firms × 20 teaching periods.
- Zero duplicate firm-period cells and zero missing raw values.
- One-way pooled, FE, and RE models use identical 200-observation samples.

## One-way selection tests

| Comparison | Statistic | df | p-value |
|---|---:|---:|---:|
| Pooled vs FE | 52.284645 | (9,188) | 1.565e-46 |
| Pooled vs RE, Breusch–Pagan LM | 754.636424 | 1 | 3.938e-166 |
| FE vs RE, conventional Hausman | 7.715151 | 2 | 0.02111914 |

## Hausman reconstruction

- FE slopes: `lvalue = 0.591847307`, `lcapital = 0.255918016`.
- RE slopes: `lvalue = 0.662453320`, `lcapital = 0.255515458`.
- Difference vector: `(-0.070606013, 0.000402559)`.
- Covariance-difference matrix:

  `[[0.00209334735, -0.00021507749], [-0.00021507749, 0.00003089961]]`
- Eigenvalues: `0.0000087095`, `0.0021155375`.
- Hausman: **χ²(2) = 7.715151, p = 0.02111914**.

## Period-adjusted correlated-effects evidence

- Two-way FE slopes: `lvalue = 0.328554135`, `lcapital = 0.076795861`.
- Period effects conditional on firm FE: **F(19,169) = 7.535040, p = 1.441e-14**.
- Mundlak current slopes: `lvalue = 0.328554135`, `lcapital = 0.076795861`.
- Firm-mean coefficients: `mean_lvalue = 0.418458450`, `mean_lcapital = 0.384909139`.
- Two-way CR1 SEs for the mean coefficients: `0.16507286`, `0.09554529`.
- Joint zero-mean test: **χ²(2) = 32.202709, p = 1.017e-07**.

## First-log-difference effect checks

- Usable transitions: **190**.
- Additional firm effects: **F(9,178) = 0.194074, p = 0.99458007**.
- Period effects: **F(18,169) = 4.844947, p = 1.144e-08**.

## Conditional model-selection interpretation

- The pooled common-intercept restriction is rejected.
- The pooled zero-random-component restriction is rejected.
- The conventional one-way Hausman null is rejected at 5% but not 1%.
- Period effects are important in the logged-level equation.
- The period-adjusted Mundlak mean restrictions are jointly rejected under the explicit two-way CR1 benchmark.
- Therefore, conditional on the logged-level form being admissible, the static candidate is two-way FE.
- The first-log-difference specification has a different effect structure: additional firm effects are redundant while period effects remain important.
- None of these tests establishes causal identification or overrides stationarity/cointegration requirements.

## Runtime status

- Independent numerical benchmark: **PASS**.
- Reader-facing R migration: **PASS**.
- Live R execution / `renv.lock`: **PENDING** because the current migration runtime has no R interpreter.
