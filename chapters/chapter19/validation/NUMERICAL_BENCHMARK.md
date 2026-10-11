# Chapter 19 Independent Numerical Benchmark

All values below were recomputed from `data/Grunfeld_PanelData_2006_2025.csv`; no printed legacy output was used as the computational source.

## Sample accounting

- Level observations: 200
- Firms: 10
- Teaching-period labels: 20
- First log differences: 190
- PVAR(1) observations: 180
- PVAR usable period clusters: 18
- Common lag-order comparison sample: 160 observations, labels 2010–2025

## Dumitrescu–Hurlin, K = 1

| Predictor | Predicted | Wbar | Ztilde | asymptotic p | block-2 p |
|---|---|---:|---:|---:|---:|
| investment growth | firm-value growth | 1.255973 | 0.175433 | 0.860740 | 0.351648 |
| investment growth | capital-stock growth | 25.152729 | 41.224979 | <1e-15 | 0.000999 |
| firm-value growth | investment growth | 0.715882 | -0.752330 | 0.451853 | 0.729271 |
| firm-value growth | capital-stock growth | 3.911196 | 4.736541 | 0.000002174 | 0.010989 |
| capital-stock growth | investment growth | 3.092745 | 3.330616 | 0.000866540 | 0.016983 |
| capital-stock growth | firm-value growth | 2.142691 | 1.698625 | 0.089390 | 0.082917 |

The block-bootstrap draws are frozen as 1-based resample indices in `reproducibility/bootstrap_block2_indices.csv`, generated once using PCG64 seed 1907. This makes the Monte Carlo benchmark reproducible across R/Python RNG implementations.

## Dumitrescu–Hurlin, K = 2

| Predictor | Predicted | Wbar | Ztilde | p |
|---|---|---:|---:|---:|
| investment growth | firm-value growth | 2.927552 | 0.567555 | 0.570337 |
| investment growth | capital-stock growth | 21.186983 | 20.211576 | 7.74e-91 |
| firm-value growth | investment growth | 1.645282 | -0.811948 | 0.416822 |
| firm-value growth | capital-stock growth | 2.581510 | 0.195274 | 0.845179 |
| capital-stock growth | investment growth | 3.278459 | 0.945071 | 0.344622 |
| capital-stock growth | firm-value growth | 4.264888 | 2.006300 | 0.044824 |

Only investment-growth → capital-stock-growth is strongly stable across both lag orders.

## Common-sample lag criteria

| p | AIC | BIC | HQ |
|---:|---:|---:|---:|
| 1 | -0.896245 | -0.358090 | -0.677719 |
| 2 | -0.910102 | -0.314287 | -0.668162 |
| 3 | -0.918685 | -0.265211 | -0.653332 |

AIC selects 3; BIC/HQ select 1. The chapter adopts p=1 as the parsimonious descriptive system.

## Two-way FE PVAR(1) coefficient matrix

Rows: current investment, firm value, capital stock growth.  
Columns: lagged investment, firm value, capital stock growth.

```text
[[-0.043297119  -0.055458818  -0.131212118]
 [ 0.137447534  -0.220983928  -0.087350122]
 [ 0.327179914   0.379884371   0.133995235]]
```

Period-clustered CR1 standard errors, 18 clusters:

```text
Investment equation: 0.086660, 0.154390, 0.031629
Firm-value equation: 0.055129, 0.114786, 0.033387
Capital equation:    0.093056, 0.252760, 0.087239
```

## Stability

Eigenvalues:

```text
 0.032919 + 0.264045 i
 0.032919 - 0.264045 i
-0.196124
```

Moduli: 0.266089, 0.266089, 0.196124. All are inside the unit circle.

## Reduced-form innovation covariance

```text
[[ 0.03646142   0.00670034  -0.00428890]
 [ 0.00670034   0.01438887   0.00113767]
 [-0.00428890   0.00113767   0.02795922]]
```

The investment/firm-value innovation correlation is 0.292527.

## Generalized response of investment growth

| Shock | h=0 | h=1 |
|---|---:|---:|
| investment growth | 0.190949 | -0.007266 |
| firm-value growth | 0.055858 | -0.010315 |
| capital-stock growth | -0.025650 | -0.021207 |

## Normalized generalized FEVD, horizon 5

```text
investment growth:     89.3036%   7.9892%   2.7073%
firm-value growth:     10.5302%  86.9241%   2.5456%
capital-stock growth:  15.6402%  11.2044%  73.1554%
```

## Residual diagnostics

| Equation | mean within rho1 | mean pair corr | mean abs corr | CD | p |
|---|---:|---:|---:|---:|---:|
| investment growth | -0.020445 | -0.107949 | 0.223501 | -3.072277 | 0.002124 |
| firm-value growth | -0.102428 | -0.106865 | 0.251236 | -3.041428 | 0.002355 |
| capital-stock growth | 0.192187 | -0.074681 | 0.387811 | -2.125445 | 0.033549 |

## Interpretation gate

These results establish predictive precedence under the chosen stationary transformation and information set. They do not identify intervention effects or structural economic shocks.
