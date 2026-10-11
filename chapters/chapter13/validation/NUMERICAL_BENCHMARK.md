# Chapter 13 Numerical Benchmark

This benchmark was independently reconstructed from the authoritative CSV using explicit matrix formulas. It is the publication reference for the R migration; live execution of `R/chapter13.R` remains a separate release gate.

## Data and coefficient specifications

- Level panel: **200 observations**, 10 firms × 20 teaching periods.
- First-log-difference panel: **190 observations**, 10 firms × 19 transitions.
- Logged-level two-way FE slopes: **0.328554135** for `lvalue`, **0.076795861** for `lcapital`.
- Period-adjusted first-log-difference slopes: **0.495709424** for `dvalue`, **-0.085692611** for `dcapital`.
- Expanded design coefficient counts: **K = 31** in levels and **K = 21** in the growth model.

## Logged-level two-way FE covariance sensitivity

| Method | SE value | p value | SE capital | p capital |
|---|---:|---:|---:|---:|
| Ordinary | 0.08624732 | 0.00019470992 | 0.03445064 | 0.027121635 |
| HC1 | 0.08632267 | 0.00019713401 | 0.03802849 | 0.045022682 |
| Firm cluster | 0.19091229 | 0.11936408 | 0.05155251 | 0.17049758 |
| Period cluster | 0.07584544 | 0.00035930811 | 0.04324475 | 0.091777908 |
| Two-way cluster | 0.18640931 | 0.11181362 | 0.05551219 | 0.19988854 |
| PCSE SUR | 0.07705556 | 3.3344819e-05 | 0.03294218 | 0.020921383 |
| PCSE diagonal | 0.08239968 | 9.9288997e-05 | 0.03370493 | 0.023950093 |
| Driscoll-Kraay | 0.07504355 | 0.00032337805 | 0.05167208 | 0.15362765 |

## Period-adjusted growth covariance sensitivity

| Method | SE value growth | p value | SE capital growth | p capital |
|---|---:|---:|---:|---:|
| Ordinary | 0.09991939 | 1.6975829e-06 | 0.04839993 | 0.078444883 |
| HC1 | 0.10101111 | 2.1580721e-06 | 0.04084024 | 0.037370891 |
| Firm cluster | 0.13841451 | 0.0059183402 | 0.04012400 | 0.061449968 |
| Period cluster | 0.07433646 | 2.9523782e-06 | 0.04192665 | 0.055881489 |
| Two-way cluster | 0.12033803 | 0.002600626 | 0.04122929 | 0.067435464 |
| PCSE SUR | 0.09608123 | 6.8860483e-07 | 0.04154711 | 0.040686416 |
| PCSE diagonal | 0.09634394 | 7.3472539e-07 | 0.04103903 | 0.038290364 |
| Driscoll-Kraay | 0.07778550 | 5.3004198e-06 | 0.03429020 | 0.022352527 |

## Cluster-based 95% intervals for the growth equation

| Method | Term | Lower | Upper |
|---|---|---:|---:|
| Firm cluster | dvalue | 0.1825941 | 0.8088248 |
| Firm cluster | dcapital | -0.1764594 | 0.0050742 |
| Period cluster | dvalue | 0.3395343 | 0.6518845 |
| Period cluster | dcapital | -0.1737772 | 0.0023920 |
| Two-way cluster | dvalue | 0.2234859 | 0.7679330 |
| Two-way cluster | dcapital | -0.1789597 | 0.0075745 |

## Reproducibility conventions

- HC1 uses `n/(n-K)` with the full expanded design dimension.
- CR1 uses `G/(G-1) * (n-1)/(n-K)`.
- Two-way clustering is firm + period − firm-period cell covariance.
- PCSE uses the balanced contemporaneous residual covariance and the same `n/(n-K)` leading multiplier.
- Driscoll–Kraay uses cross-sectional score aggregates, Bartlett weights, bandwidth 2, and the teaching multiplier `T/(T-2)`.
- Cluster p-values use `t_9` for firm clustering, `t_19`/`t_18` for period clustering, and conservative `t_9` for two-way clustering.

## Interpretation benchmark

- `dvalue` remains positive and statistically significant under every reported covariance sensitivity.
- `dcapital` is negative but the firm-, period-, and two-way-cluster 95% intervals all include zero.
- Covariance correction does not resolve the logged-level RESET rejection or serial-persistence evidence from Chapter 12.

## Runtime status

- Independent numerical benchmark: **PASS**.
- R source construction: **PASS**.
- Live R execution / CR2 package output / `renv.lock`: **PENDING** because the migration runtime has no R interpreter.
