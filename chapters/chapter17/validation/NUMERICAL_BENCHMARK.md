# Chapter 17 Independent Numerical Benchmark

Dataset: 10 firms x 20 teaching-period labels = 200 level observations. The labels 2006–2025 are relabelled original 1935–1954 Grunfeld observations.

## Cross-sectional dependence in first log differences

- dlinvest: average pair correlation=0.335002806; CD=9.795610355; p=1.17585e-22
- dlvalue: average pair correlation=0.501975729; CD=14.677962579; p=8.92315e-49
- dlcapital: average pair correlation=0.234883187; CD=6.868074368; p=6.50743e-12

## Firm-specific Engle–Granger benchmark

Constant cointegrating regression; maximum one residual-ADF lag selected by AIC; MacKinnon response-surface p-values. Rejections at 5%: 5/10.

Naive Fisher combination: 100.125576878815; chi-square(20) independence-reference p=1.19607691686e-12. Strong cross-sectional dependence means this is not an unconditional panel p-value.

## Static long-run comparison

- One-way FE: lvalue=0.591847307; lcapital=0.255918016.
- Two-way FE: lvalue=0.328554135; lcapital=0.076795861.

## Transparent two-way DOLS q=1

- N=170; teaching labels 2008–2024 (17 period clusters).
- lvalue=0.335917039; period-CR1 SE=0.093269722; p=0.00239128979298; CI=[0.138194061, 0.533640017].
- lcapital=0.325829501; period-CR1 SE=0.039887842; p=4.22611357108e-07; CI=[0.241271055, 0.410387948].

## Conditional ECM

- N=170; teaching labels 2009–2025 (17 period clusters).
- ECT(-1)=-0.405999948; SE=0.072024827; p=3.71130130888e-05.
- dlinvest response to dlvalue=0.422067155; SE=0.084008057; p=0.000124656024431.
- dlinvest response to dlcapital=-0.200218785; SE=0.109226244; p=0.0854662372537.
- Joint current-growth test: F(2,16)=15.041234454551; p=0.000211190292284.
- Remaining disequilibrium fraction=0.594000052; half-life=1.330733901 periods.

## R-specific live gates

`pco::pedroni99m()`, `aTSA::coint.test()`, and `urca::ca.jo()` must be executed in the final R environment. Their package-native output is intentionally not fabricated in this migration runtime. No pooled residual ADF result is labelled as Kao.
