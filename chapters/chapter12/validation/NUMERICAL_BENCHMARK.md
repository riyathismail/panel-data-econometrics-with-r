# Chapter 12 Numerical Benchmark

This benchmark was independently recomputed from the authoritative CSV using a separate implementation. The final R release gate requires live execution of `R/chapter12.R`; the values below are not copied from software screenshots.

## Target equations

| Equation | N | value slope | capital slope | R2 |
|---|---:|---:|---:|---:|
| Logged-level two-way FE | 200 | 0.328554 | 0.076796 | 0.97864028 |
| First-log-difference + period FE | 190 | 0.495709 | -0.085693 | 0.49253074 |

## Groupwise residual-variance LR diagnostics

| Equation | Group | LR | df | p |
|---|---|---:|---:|---:|
| Level two-way FE | Firm | 28.884574 | 9 | 0.00067774 |
| Level two-way FE | Teaching period | 36.077979 | 19 | 0.01032517 |
| Growth + period FE | Firm | 17.795230 | 9 | 0.03762494 |
| Growth + period FE | Teaching period | 39.085475 | 18 | 0.00277529 |

## Within-firm residual persistence

- Logged-level two-way FE: slope **0.576360**, firm-CR1 SE **0.050684**, pairs **190**, p for `rho=0` **1.22e-06**.
- Growth + period FE: slope **-0.068979**, firm-CR1 SE **0.091593**, pairs **180**, p for `rho=0` **0.470630**.
- Wooldridge/Drukker level-error null `rho=-0.5`: **t(9)=4.705811**, **p=0.001111**.

## Residual cross-sectional dependence

| Model | Mean rho | Mean |rho| | BP LM | Scaled LM | CD | CD p |
|---|---:|---:|---:|---:|---:|---:|
| Level firm FE only | 0.237120 | 0.320627 | 136.491920 | 9.644095 | 7.113595 | 1.13059e-12 |
| Level two-way FE | -0.105024 | 0.290015 | 106.346294 | 6.466467 | -3.150724 | 0.00162867 |
| Growth no period FE | 0.266571 | 0.300793 | 112.497247 | 7.114835 | 7.794643 | 6.45909e-15 |
| Growth + period FE | -0.105568 | 0.230600 | 65.501532 | 2.161051 | -3.086843 | 0.00202294 |

## Estimator-relevant collinearity

- Two-way-demeaned logged regressors: correlation **0.186684**, VIF **1.036109**.
- Period-residualized growth regressors: correlation **-0.062030**, VIF **1.003863**.

## Residual distribution

| Model | SD | Skewness | Pearson kurtosis | JB | p |
|---|---:|---:|---:|---:|---:|
| Level two-way FE | 0.211235 | -0.075487 | 3.677849 | 4.018934 | 0.134060 |
| Growth + period FE | 0.187638 | 0.101406 | 3.776974 | 5.104829 | 0.077893 |

## Ramsey RESET

| Model | Conventional F | Conventional p | Two-way CR1 chi-square(2) | Robust p |
|---|---:|---:|---:|---:|
| Level two-way FE | 5.145871 | 0.006782 | 9.694844 | 0.007849 |
| Growth + period FE | 0.487666 | 0.614930 | 0.697045 | 0.705730 |

## Influence

- Level threshold `4/200 = 0.020000`; **14** observations exceed it.
- Growth threshold `4/190 = 0.021053`; **11** observations exceed it.

Largest level Cook distances:
- Firm 10 / label 2014: **0.070190**
- Firm 7 / label 2015: **0.053689**
- Firm 10 / label 2015: **0.047393**

Largest growth Cook distances:
- Firm 5 / label 2014: **0.104394**
- Firm 1 / label 2007: **0.068231**
- Firm 10 / label 2014: **0.047924**

## Status

- Independent numerical benchmark: **PASS**.
- R source contains hard assertions for the main published benchmarks: **PASS**.
- Live R execution / `renv.lock`: **PENDING** because R is not installed in the migration runtime.
