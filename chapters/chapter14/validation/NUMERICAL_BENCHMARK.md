# Chapter 14 Numerical Benchmark

This benchmark was independently reconstructed from the authoritative Grunfeld teaching CSV. It is the reporting-layer benchmark for Chapter 14; no number below is copied from a screenshot or table-export artifact.

## Primary reporting model

Specification: first log difference of investment on first log differences of value and capital, with complete transition-period fixed effects.

- Observations: **190**
- Firms: **10**
- Transition periods: **19**
- Residual degrees of freedom: **169**
- `dlvalue` coefficient: **0.495709424**
- `dlcapital` coefficient: **-0.085692611**
- R-squared: **0.492530737**
- Adjusted R-squared: **0.432475202**

## Cluster-reference reporting results

| Term | Covariance | SE | t | Reference p | 95% lower | 95% upper | Ref df |
|---|---|---:|---:|---:|---:|---:|---:|
| `dlvalue` | Firm cluster | 0.138414509 | 3.581340 | 0.00591834 | 0.182594052 | 0.808824796 | 9 |
| `dlcapital` | Firm cluster | 0.040124002 | -2.135695 | 0.06144997 | -0.176459410 | 0.005074188 | 9 |
| `dlvalue` | Period cluster | 0.074336462 | 6.668456 | 0.000002952 | 0.339534312 | 0.651884536 | 18 |
| `dlcapital` | Period cluster | 0.041926650 | -2.043870 | 0.05588149 | -0.173777234 | 0.002392011 | 18 |
| `dlvalue` | Two-way cluster | 0.120338033 | 4.119308 | 0.00260063 | 0.223485880 | 0.767932968 | 9 |
| `dlcapital` | Two-way cluster | 0.041229291 | -2.078440 | 0.06743546 | -0.178959748 | 0.007574525 | 9 |

The reference degrees of freedom are an explicit book reporting convention: `G-1` for one-way clustering and the smaller cluster dimension minus one for the displayed two-way sensitivity. They are not described as exact finite-sample distributions.

## Exact finite-change interpretation for value growth

For coefficient `0.495709424`, the exact dependent-variable percentage change for an `x%` regressor change is:

`100 * ((1 + x/100)^beta - 1)`.

| Value change | Linear approximation | Exact fitted change | Exact lower | Exact upper |
|---:|---:|---:|---:|---:|
| 1% | 0.495709% | 0.494466% | 0.338419% | 0.650755% |
| 5% | 2.478547% | 2.448059% | 1.670391% | 3.231676% |
| 10% | 4.957094% | **4.838004%** | **3.289039%** | **6.410198%** |
| 20% | 9.914188% | 9.458852% | 6.386066% | 12.620391% |

## Exact 10% capital-stock interpretation

Using the period-cluster coefficient and interval:

- fitted investment change: **-0.813412%**;
- transformed lower limit: **-1.642633%**;
- transformed upper limit: **0.022801%**.

The transformed interval crosses zero, so Chapter 14 does not report a definitive negative association at the conventional 5% threshold.

## Effect-selection evidence carried forward

- Period effects after first differencing: **F(18,169)=4.844947**, p **1.14e-08**.
- Additional firm intercepts after first differencing: **F(9,178)=0.194074**, p **0.994580**.

## Diagnostic evidence carried forward from independently verified Chapter 12

- Firmwise growth-residual variance LR: **17.795230**, df 9, p **0.03762494**.
- Periodwise growth-residual variance LR: **39.085475**, df 18, p **0.00277529**.
- Growth residual AR(1) slope: **-0.068979**, firm-CR1 SE **0.091593**, p **0.470630**.
- Growth residual Pesaran CD: **-3.086843**, p **0.00202294**.
- Growth RESET: **F(2,167)=0.487666**, p **0.614930**.

## Reporting conclusion

- The `dlvalue` coefficient is positive and its 95% interval excludes zero under firm, period, and two-way clustered sensitivity calculations.
- The `dlcapital` interval crosses zero under all three cluster choices.
- These are conditional associations, not identified causal effects.

## Status

- Independent numerical benchmark: **PASS**.
- Manuscript hard-coded case numbers reconciled to benchmark: **PASS**.
- R source contains hard assertions for primary coefficients, fit, covariance rows, intervals, and exact finite changes: **PASS**.
- Live R execution / generated `modelsummary` exports / final `renv.lock`: **PENDING**, because R is not installed in the migration runtime.
