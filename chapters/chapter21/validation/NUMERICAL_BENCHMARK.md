# Chapter 21 Independent Numerical Benchmark

All values below were independently reconstructed from `data/Grunfeld_PanelData_2006_2025.csv`. Teaching labels 2006--2025 relabel original Grunfeld 1935--1954 and are not modern dates.

## Stable period-adjusted growth model

- N = 190
- beta_value = 0.495709423973
- beta_capital = -0.085692611442
- period-CR1 SE(value) = 0.074336462311
- period-CR1 SE(capital) = 0.041926649636
- SSR = 6.654347013855
- R2 = 0.492530736506

## Known teaching-label 2020 slope split

- pre value slope = 0.520012880400
- post value slope = 0.410119460975
- value slope change = -0.109893419425
- period-CR1 SE(change) = 0.170057905680
- 95% CI(change) = [-0.467171821584, 0.247384982734]
- pre capital slope = -0.085666761959
- post capital slope = -0.091391196267
- capital slope change = -0.005724434308
- period-CR1 SE(change) = 0.133742794509
- 95% CI(change) = [-0.286707619016, 0.275258750400]
- joint period-clustered F(2,18) = 0.214230145316
- p = 0.809191077671
- classical SSR F(2,167) = 0.102601225843

## Unknown common-break search

Candidates are first-post labels 2012--2021, enforcing at least five teaching periods in each regime.

- observed joint sup F = 3.027703400087 at label 2012
- pointwise p at argmax = 0.073542467149
- supplied-bootstrap B = 4999
- search-adjusted p = 0.3894
- 95% bootstrap critical value (higher empirical quantile) = 9.083234293137
- value-only sup F = 5.680097057703 at label 2012
- value-only search-adjusted p = 0.1438
- capital-only sup F = 1.290706415277 at label 2016
- capital-only search-adjusted p = 0.8754

The fixed bootstrap-weight matrix is stored at `reproducibility/bootstrap_weights_seed2107.csv`, so the published Monte Carlo benchmark does not depend on the random-number generator used by the runtime.

## Rolling seven-period slopes

- value slope range = 0.350836287615 to 0.677895660282
- value slope positive in all 13 windows
- largest value slope window = 2015-2021
- capital slope range = -0.263572189854 to 0.049820422334

## Residual-dispersion sensitivity

- mean MSE, teaching labels 2007--2019 = 0.042532945538
- mean MSE, teaching labels 2020--2025 = 0.018751068232
- later/earlier ratio = 0.440859855685
- Welch t = 2.812639606708
- p = 0.011996039140
- df = 16.972079023324

This residual-dispersion comparison is a generated-residual sensitivity diagnostic, not a definitive variance-break test.
