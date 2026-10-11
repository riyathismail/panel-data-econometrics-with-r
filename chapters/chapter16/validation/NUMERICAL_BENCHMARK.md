# Chapter 16 Independent Numerical Benchmark

Authoritative data: `data/raw/Grunfeld_PanelData_2006_2025.csv`.

## Dynamic logged levels

| Quantity | Period effects only | Two-way FE |
|---|---:|---:|
| Lagged log investment | 0.939768 | 0.593788 |
| Conventional SE | 0.032170 | 0.070868 |
| log(value) | 0.063556 | 0.163462 |
| log(capital) | 0.008236 | -0.050730 |
| N | 190 | 190 |
| R-squared | 0.980992291 | 0.985171132 |

Two-way FE conditional quantities: half-life 1.329821 periods; long-run value elasticity 0.402404; long-run capital elasticity -0.124886. These are diagnostic only.

## Period-adjusted dynamic first-log-difference model

Coefficients: lagged investment growth -0.005576702; market-value growth 0.469851785; capital growth -0.148094835. N=180; R-squared=0.488781260.

Using the book's explicit CR1 period-cluster convention with 18 clusters and t(17):

| Term | SE | t | p |
|---|---:|---:|---:|
| Lagged investment growth | 0.098251820 | -0.056759 | 0.955399 |
| Market-value growth | 0.095799002 | 4.904558 | 0.000133862 |
| Capital growth | 0.054390549 | -2.722805 | 0.0144689 |

These differ slightly from the legacy EViews-cluster row because the R edition freezes an explicit CR1 formula instead of a software-specific panel-effect finite-sample convention.

## Anderson–Hsiao 2SLS illustration

- IV lag coefficient: 0.498599
- conventional SE: 0.779410
- p-value: 0.523280
- excluded-instrument first-stage F(1,159): 2.101270380
- first-stage p: 0.149146364
- exactly identified: no overidentification test.

## Instrument proliferation

For T=20, theoretical uncollapsed dynamic instruments: all lags 2+ for one variable = 171; lags 2–3 for one variable = 35; lags 2–3 for three variables = 105 before time dummies/other instruments.

## GMM release position

No GMM coefficient is adopted as a case benchmark. Optional `plm::pgmm()` code must report actual instrument columns/rank, AR(1), AR(2), and Hansen–Sargan results when executed. With N=10, these are teaching sensitivities rather than final inference.
