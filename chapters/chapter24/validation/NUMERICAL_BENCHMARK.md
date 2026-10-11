# Chapter 24 Numerical Benchmark

Independent capstone reconstruction from the authoritative Grunfeld teaching CSV.

## Data integrity

- Raw SHA-256: `ed05316c9371b7a6f663c6eb1e6edfb980e0533dafe1c671f6a93e6410eab705`
- 200 level observations = 10 firms × 20 teaching periods.
- 190 complete first-log-difference observations.
- Zero duplicate firm-period cells; zero missing raw values.

## Logged-level estimator ladder

- Pooled OLS: `lvalue = 0.773256744482`, `lcapital = 0.380533499740`.
- One-way FE: `lvalue = 0.591847307140`, `lcapital = 0.255918016449`.
- Swamy-Arora RE: `lvalue = 0.662453320092`, `lcapital = 0.255515457857`, `theta = 0.868933010359`.
- Two-way FE: `lvalue = 0.328554134946`, `lcapital = 0.076795860596`.

## Core selection evidence

- Pooled vs firm FE: **F(9,188) = 52.284645443, p = 1.565e-46**.
- Breusch-Pagan RE LM from Chapter 10/11 release benchmark: **754.636423561**.
- Conventional Hausman from Chapter 11 release benchmark: **χ²(2) = 7.715151276, p = 0.02111914**.
- Additional firm effects after first differencing: **F(9,178) = 0.194074151, p = 0.99458007**.
- Period effects after first differencing: **F(18,169) = 4.844946975, p = 1.144e-08**.

## Principal short-run model

- `dlvalue = 0.495709423973`.
- `dlcapital = -0.085692611442`.
- `N = 190`.
- `R² = 0.492530736506`.
- `Adjusted R² = 0.432475202364`.
- `SSR = 6.654347013855`.

## CR1 covariance sensitivity

| covariance      | term      |      estimate |    std.error |   statistic |        p.value |     conf.low |     conf.high |   df.reference |
|:----------------|:----------|--------------:|-------------:|------------:|---------------:|-------------:|--------------:|---------------:|
| Firm cluster    | dlvalue   |  0.495709424  | 0.138414509  |  3.58134006 | 0.00591834022  |  0.182594052 | 0.808824796   |              9 |
| Firm cluster    | dlcapital | -0.0856926114 | 0.0401240022 | -2.13569452 | 0.0614499675   | -0.17645941  | 0.00507418755 |              9 |
| Period cluster  | dlvalue   |  0.495709424  | 0.0743364623 |  6.66845594 | 2.95237821e-06 |  0.339534312 | 0.651884536   |             18 |
| Period cluster  | dlcapital | -0.0856926114 | 0.0419266496 | -2.04386976 | 0.0558814892   | -0.173777234 | 0.00239201085 |             18 |
| Two-way cluster | dlvalue   |  0.495709424  | 0.120338033  |  4.11930801 | 0.00260062603  |  0.22348588  | 0.767932968   |              9 |
| Two-way cluster | dlcapital | -0.0856926114 | 0.0412292914 | -2.07844007 | 0.0674354642   | -0.178959748 | 0.00757452538 |              9 |

## Finite-change interpretation

- Exact fitted change for a 10% increase in market value: **4.838004%**.
- Exact fitted change for a 20% increase in market value: **9.458852%**.

## Cross-chapter status

The final-model and core estimator quantities above were independently recomputed in Chapter 24. LM, Hausman, advanced-chapter quantities, forecast metrics, PVAR, heterogeneous-panel, break, DiD, and nonlinear results are reconciled against the already released chapter-specific numerical benchmarks and recorded in `CROSS_CHAPTER_LEDGER.csv`.

## Runtime status

- Independent Python reconstruction: **PASS**.
- R source/test/targets architecture: **PASS by static review**.
- Live R execution and real `renv.lock`: **PENDING** because R is unavailable in the migration runtime.
