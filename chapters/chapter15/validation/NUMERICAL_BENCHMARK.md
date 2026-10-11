# Chapter 15 Numerical Benchmark

This benchmark consolidates the independently verified decision chain from Chapters 11-14 and recomputes the integrated growth model, nested effect tests, diagnostics, and cluster-reference inference directly from the authoritative raw CSV.

## Data provenance

- SHA-256: `ed05316c9371b7a6f663c6eb1e6edfb980e0533dafe1c671f6a93e6410eab705`
- Level observations: **200**
- Firms: **10**
- Teaching periods: **20**
- Valid first-log-difference transitions: **190**
- Duplicate firm-period cells: **0**
- Missing raw modelling values: **0**

## Selection evidence

- Pooled levels vs firm FE: **F(9,188) = 52.284645**, p < 0.001.
- Pooled levels vs RE component: **LM = 754.636424**, p < 0.001.
- FE vs RE conventional Hausman: **chi-square(2) = 7.715151**, p = **0.02111914**.
- Period-adjusted Mundlak means: **chi-square(2) = 32.202709**, p = **1.017e-07**.
- Growth firm effects vs pooled: **F(9,178) = 0.194074**, p = **0.99458007**.
- Growth period effects vs pooled: **F(18,169) = 4.844947**, p = **1.14e-08**.
- Growth firm effects given period: **F(9,160) = 0.300909**, p = **0.97359088**.
- Growth period effects given firm: **F(18,160) = 4.681860**, p = **3.14e-08**.

## Final period-adjusted growth model

- `dlvalue`: **0.495709424**.
- `dlcapital`: **-0.085692611**.
- R-squared: **0.492530737**.
- Adjusted R-squared: **0.432475202**.
- Residual df: **169**.

### Primary period-clustered inference

- `dlvalue`: SE **0.074336462**, 95% CI **[0.339534312, 0.651884536]**, reference p **2.95237821e-06**.
- `dlcapital`: SE **0.041926650**, 95% CI **[-0.173777234, 0.002392011]**, reference p **0.0558814892**.

## Growth-model diagnostics

- Firm variance LR: **17.795230**, p **0.03762494**.
- Period variance LR: **39.085475**, p **0.00277529**.
- Residual AR(1) slope: **-0.068979**, firm-CR1 SE **0.091593**, p **0.470630**.
- Pesaran CD: **-3.086843**, p **0.00202294**.
- Ramsey RESET: **F(2,167) = 0.487666**, p **0.614930**.
- Jarque-Bera: **5.104829**, p **0.077893**.

## Integrated conclusion

The reproducible decision path supports a first-log-difference conditional mean with complete transition-period effects. Additional firm growth intercepts are redundant. The conditional mean does not show detected first-order persistence or RESET failure under the Chapter 12 diagnostics, while heteroskedasticity and cross-sectional dependence remain. Period-clustered inference is the primary case convention and two-way clustering is retained as sensitivity evidence.

## Runtime status

- Independent integrated numerical benchmark: **PASS**.
- R source and `_targets.R` dependency graph created: **PASS**.
- Live `targets::tar_make()` execution: **PENDING** because R is not installed in the migration runtime.
- Final `renv.lock`: **PENDING** until the successful production R environment is snapshotted.
