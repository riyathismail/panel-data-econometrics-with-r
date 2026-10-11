# Chapter 8 Numerical Benchmark

This benchmark was independently recomputed from the authoritative Grunfeld teaching CSV and is used to audit the R migration. It does not substitute for live execution of `R/chapter08.R`; that remains a separate release gate.

## Panel and transformation integrity

- Level observations: **200**
- Firms: **10**
- Teaching periods per firm: **20**
- Valid first-log-difference observations: **190**
- The first teaching-period observation of every firm is mechanically lost after differencing.
- Mean first log differences:
  - `dlinvest`: **0.065406**
  - `dlvalue`: **0.038198**
  - `dlcapital`: **0.151537**

For firm 1 from teaching label 2006 to 2007, the log changes are **0.209959**, **0.414938**, and **2.933097** for investment, value, and capital respectively.

## Baseline first-log-difference model

\[
\widehat{\Delta\ln(invest)}
=0.0543445
+0.5788460\,\Delta\ln(value)
-0.0729166\,\Delta\ln(capital).
\]

| Term | Estimate | SE | 95% CI |
|---|---:|---:|---:|
| Intercept | 0.054345 | 0.018821 | [0.017216, 0.091473] |
| `dlvalue` | 0.578846 | 0.079660 | [0.421697, 0.735995] |
| `dlcapital` | -0.072917 | 0.050564 | [-0.172666, 0.026833] |

Model fit: **N = 190**, **R² = 0.230661**, adjusted **R² = 0.222433**, **DW = 2.014729**.

## Covariance sensitivity

| Term | Ordinary | HC1 | Firm cluster | Period cluster | Two-way cluster |
|---|---:|---:|---:|---:|---:|
| Intercept | 0.018821 | 0.018850 | 0.007553 | 0.033545 | 0.028758 |
| `dlvalue` | 0.079660 | 0.064462 | 0.069869 | 0.104739 | 0.108151 |
| `dlcapital` | 0.050564 | 0.038310 | 0.030415 | 0.042246 | 0.035243 |

The CR1 benchmark uses `G/(G-1) * (n-1)/(n-k)` for each cluster dimension. Two-way clustering is the firm component plus the period component minus the firm-period intersection component.

## Period and firm effects after differencing

With period indicators:

- `dlvalue` = **0.495709**
- `dlcapital` = **-0.085693**
- **R² = 0.492531**
- adjusted **R² = 0.432475**
- **DW = 2.048397**
- joint period test: **F(18,169) = 4.844947**, **p = 1.14444e-08**

With firm indicators added to the differenced equation:

- joint test: **F(9,178) = 0.194074**, **p = 0.994580**

The firm-dummy test concerns firm-specific average growth intercepts, not the original time-invariant level effects, which have already been differenced out.

## Residual diagnostics

- Adjacent within-firm residual correlation: **-0.039443**
- Jarque-Bera: **0.498460**, **p = 0.779401**

The empirical residual correlation need not equal the theoretical **-0.5** because that theoretical result requires serially independent, homoskedastic level innovations and an otherwise correctly specified model.

## Arithmetic first-difference comparison

\[
\widehat{\Delta invest}
=-1.818890
+0.089762\,\Delta value
+0.291767\,\Delta capital.
\]

- **R² = 0.408877**
- **DW = 1.612256**
- Jarque-Bera = **383.565**, p approximately **5.13e-84**
- condition number approximately **434.17**, versus approximately **4.80** for the log-difference model

The arithmetic model is therefore not preferred merely because its R² is higher.

## Release status

- Independent numerical audit: **PASS**
- Manual FD benchmark: **PASS**
- Period/firm nested tests: **PASS**
- Covariance benchmark: **PASS**
- Live `plm(model = "fd")` equivalence test: **PENDING live R execution**
