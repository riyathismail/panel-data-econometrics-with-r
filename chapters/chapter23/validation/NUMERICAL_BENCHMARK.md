# Chapter 23 Independent Numerical Benchmark

Authoritative data: `data/Grunfeld_PanelData_2006_2025.csv`.

The binary teaching outcome is constructed as `1[Delta log(invest) > 0]`. The original Grunfeld years 1935–1954 are relabelled 2006–2025 only as teaching-period identifiers.

## Binary outcome audit

- Usable observations: **190**
- Positive-growth events: **117**
- Non-events: **73**
- Event rate: **0.615789474**
- Positive events by firm: **15, 10, 11, 10, 10, 15, 12, 12, 11, 11**
- Teaching label 2022: event rate **1.0** for all ten firms; original Grunfeld year **1951**.

## Two-way fixed-effects LPM

- `gvalue`: **0.958795342**
- `gcapital`: **-0.098249288**
- fitted range: **[-0.320078285, 1.384325680]**
- observations outside [0,1]: **19**

Clustered standard errors:

| Covariance | gvalue SE | gcapital SE |
|---|---:|---:|
| Firm CR1 | 0.317917447 | 0.088105518 |
| Period CR1 | 0.170861482 | 0.112104655 |
| Two-way CR1 | 0.292930647 | 0.110654621 |

## Firm-dummy logit with teaching-period trend

- `gvalue`: **6.235810524**
- `gcapital`: **-0.888360703**
- `trend`: **0.031538283**
- log likelihood: **-99.513001263**
- intercept-only log likelihood: **-126.556684135**
- McFadden pseudo-R²: **0.213688301**
- firm-effects-plus-trend restricted log likelihood: **-121.937712357**
- LR test of `gvalue=gcapital=0`: **44.849422189**, chi-square(2) p **1.8242e-10**

Logit clustered standard errors:

| Covariance | gvalue SE | gcapital SE |
|---|---:|---:|
| Firm CR1 | 1.456111337 | 0.443535499 |
| Period CR1 | 1.427449448 | 0.513778107 |
| Two-way CR1 | 1.656720394 | 0.477264289 |

## Probability effects

For a 10% firm-market-value increase, `Delta log(value)=log(1.10)=0.095310180`.

- Logit odds ratio, value: **1.811827895**
- Logit odds ratio, capital: **0.918815610**
- Logit AME, value: **1.094722339**
- Logit AME, capital: **-0.155955397**
- Logit exact average discrete probability change for 10% value increase: **0.097995928** = **9.7996 percentage points**

## Probit sensitivity

- `gvalue`: **3.715630862**
- `gcapital`: **-0.526048253**
- `trend`: **0.023000731**
- AME value: **1.093494189**
- AME capital: **-0.154813739**
- exact 10% value probability change: **0.098447581** = **9.8448 percentage points**

## Conditional fixed-effects logit

- `gvalue`: **5.850297170**, SE **1.128894910**
- `gcapital`: **-0.835535254**, SE **0.582749417**
- `trend`: **0.029515925**, SE **0.032848435**
- 10% value odds ratio: **1.746463481**
- all ten firms have within-outcome variation and remain in the conditional likelihood.

## Prediction diagnostics for firm-dummy logit

At threshold 0.5:

- TN = **36**
- FP = **37**
- FN = **21**
- TP = **96**
- accuracy = **0.694736842**
- sensitivity = **0.820512821**
- specificity = **0.493150685**
- AUC = **0.801662569**
- Brier score = **0.177447089**
- log loss = **0.523752638**

Calibration quintiles reproduce means/event rates approximately:

1. 0.226217 / 0.263158
2. 0.496308 / 0.421053
3. 0.660685 / 0.605263
4. 0.779461 / 0.842105
5. 0.916275 / 0.947368

## Leave-one-firm-out logit

- `gvalue` coefficient range: **[5.369206723, 6.806538090]**
- `gcapital` coefficient range: **[-1.096466967, -0.535680545]**

All empirical values above were independently recomputed from the raw CSV using Python/statsmodels/scipy. The supplied R script embeds corresponding assertions; live R execution remains pending in the migration runtime.
