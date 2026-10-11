# Chapter 18 Numerical Benchmark

Dataset: 10 firms x 20 teaching-period labels = 200 levels observations. Original Grunfeld 1935-1954 observations are sequentially relabelled 2006-2025; evaluation labels 2021-2025 correspond to original 1950-1954.

## Rolling design
- Evaluation origins: 2021-2025.
- Forecasts: 50 firm-period observations.
- Conditional training n: 140, 150, 160, 170, 180.
- Lagged-information training n: 130, 140, 150, 160, 170.

## Correct rolling conditional coefficients

|           year |        n_cond |         n_lag |    constant |      gvalue |     gcapital |       smear |
|---------------:|--------------:|--------------:|------------:|------------:|-------------:|------------:|
| 2021.000000000 | 140.000000000 | 130.000000000 | 0.048982632 | 0.558015393 | -0.068869347 | 1.030928981 |
| 2022.000000000 | 150.000000000 | 140.000000000 | 0.044497686 | 0.553681207 | -0.066635202 | 1.029946068 |
| 2023.000000000 | 160.000000000 | 150.000000000 | 0.056866704 | 0.586031298 | -0.075505040 | 1.029413862 |
| 2024.000000000 | 170.000000000 | 160.000000000 | 0.059896803 | 0.579324606 | -0.076644602 | 1.027997125 |
| 2025.000000000 | 180.000000000 | 170.000000000 | 0.060895192 | 0.580214986 | -0.075759384 | 1.026660923 |

Note: the legacy verification note contained a transcription mismatch in several year-by-year `gcapital` values. The migrated benchmark above is recomputed directly from the authoritative CSV; the aggregate legacy forecast metrics already correspond to these direct forecasts.

## Overall growth accuracy

|                             |        RMSE |         MAE |   Mean error |    Theil U1 |
|:----------------------------|------------:|------------:|-------------:|------------:|
| Zero growth                 | 0.226443983 | 0.187705379 |  0.107403429 | 1.000000000 |
| Pooled historical mean      | 0.208732515 | 0.166725036 |  0.045470017 | 0.721641236 |
| Firm historical mean        | 0.208766797 | 0.168221686 |  0.045470017 | 0.713961275 |
| Conditional contemporaneous | 0.175860672 | 0.142549154 |  0.015912706 | 0.503078491 |
| Lagged-information ex ante  | 0.204945253 | 0.166739764 |  0.038331951 | 0.678186799 |

Conditional RMSE improvement vs zero growth: 22.338112%.
Lagged-information RMSE improvement vs zero growth: 9.494061%.

Correlation(actual, conditional): 0.482675393994.

Theil decomposition: bias 0.008187486974, variance 0.442287544548, covariance 0.549524968478.

## Level reconstruction

|                         |         RMSE |          MAE |         MAPE |
|:------------------------|-------------:|-------------:|-------------:|
| Conditional median      | 60.295613200 | 27.843922878 | 14.263798291 |
| Smearing-corrected mean | 56.142509261 | 26.994431020 | 14.777189555 |
| No-change level         | 80.165966233 | 38.096200000 | 17.402366203 |

Conventional OLS prediction interval coverage: 1.000000.
Mean interval width: 0.961905035029 log-growth points.
