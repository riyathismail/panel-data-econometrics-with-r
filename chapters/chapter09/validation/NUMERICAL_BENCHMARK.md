# Chapter 9 Numerical Benchmark

This benchmark was independently recomputed from the authoritative Grunfeld teaching CSV. It is the migration reference for the R chapter; final live R execution remains a separate release gate.

## Panel integrity

- Level observations: **200**
- Firms: **10**
- Teaching periods: **20**
- Duplicate firm-period cells: **0**
- Missing analytical level values: **0**

## One-way firm fixed effects

- `log(value)` slope: **0.591847307**
- `log(capital)` slope: **0.255918016**
- Conventional SEs: **0.08823668**, **0.02670224**
- RSS: **16.40153977**
- Residual df: **188**
- Overall LSDV R²: **0.96054572**
- Within R²: **0.56440982**
- Stacked DW descriptive statistic: **0.80012040**

Manual within slopes are numerically identical to the LSDV slopes.

## Sum-to-zero normalization

- Common intercept: **-0.84692754**
- Minimum firm effect: **-1.12043632** (firm 10)
- Maximum firm effect: **0.92228362** (firm 2)
- Sum of normalized firm effects: **4.441e-16**

## Two-way fixed effects

- `log(value)` slope: **0.328554135** (SE 0.08624732)
- `log(capital)` slope: **0.076795861** (SE 0.03445064)
- RSS: **8.87944973**
- Residual df: **169**
- Overall LSDV R²: **0.97864028**
- Stacked DW descriptive statistic: **0.92242490**

## Fixed-effects tests

| Test | df1 | df2 | F | p-value |
|---|---:|---:|---:|---:|
| Firm effects vs pooled | 9 | 188 | 52.284645 | 1.56468e-46 |
| Period effects vs pooled | 19 | 178 | 0.867486 | 0.623478 |
| Period effects | firm effects | 19 | 169 | 7.535040 | 1.44105e-14 |
| Firm effects | period effects | 9 | 169 | 92.426509 | 1.46673e-60 |
| Joint firm + period effects | 28 | 169 | 33.018323 | 1.73635e-54 |

## One-way FE covariance sensitivity

| Covariance | SE value | SE capital |
|---|---:|---:|
| Conventional | 0.08823668 | 0.02670224 |
| Firm cluster | 0.13008275 | 0.07042436 |
| Period cluster | 0.05647732 | 0.05305235 |
| Two-way cluster | 0.11180064 | 0.07509674 |

## Connection to first differences

- Firm effects after FD: **F(9,178) = 0.194074**, p = **0.994580**.
- Period effects after FD: **F(18,169) = 4.844947**, p = **1.14444e-08**.

## Status

- Independent numerical benchmark: **PASS**.
- Reader-facing EViews implementation removed: **PASS**.
- Live R execution: **PENDING** because R is not installed in the migration runtime.
