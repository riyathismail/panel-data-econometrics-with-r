# Chapter 22 Independent Numerical Benchmark

## Data provenance
- Authoritative input: `data/Grunfeld_PanelData_2006_2025.csv`
- SHA-256: `ed05316c9371b7a6f663c6eb1e6edfb980e0533dafe1c671f6a93e6410eab705`
- Levels: 200 = 10 firms × 20 teaching labels.
- First log differences: 190.
- Teaching labels 2006–2025 correspond sequentially to original Grunfeld 1935–1954.
- Synthetic adoption at teaching label 2018 corresponds to original 1947.
- Treated firms: 1–5; controls: 6–10.
- Treated-post observations: 40.
- Planted effect: +0.08 log points in `dlinvest_sim` only.

## Raw two-by-two means
- Control pre: 0.066386833
- Control post: 0.063267845
- Treated pre: 0.073727603
- Treated post: 0.134752285
- Raw DiD: 0.064143669065
- Exact growth-factor conversion: 6.624557%

## Covariate-adjusted two-way fixed effects
- treatment: 0.080589996522
- dlvalue: 0.484802029736
- dlcapital: -0.105153459077
- difference from planted 0.08: 0.000589996522
- exact growth-factor conversion: 8.392639%

## Treatment inference
- Ordinary SE: 0.059706861187; conventional p=0.179011167
- Firm CR1 SE: 0.057034318373; t(9)=1.413008848; p=0.191290177; CI=[-0.048430595311, 0.209610588355]
- Period CR1 SE: 0.069887160209; t(18)=1.153144530; p=0.263934707
- Two-way CR1 SE: 0.069787004096; t(9)=1.154799487; p=0.277911983
- Firm-cluster CI exact percentage transform: [-4.7277%, 23.3198%]

## Event study
Reference: teaching label 2017 (`k=-1`).
- k≤−5: coef=0.041879304, firm CR1 SE=0.157258409
- k=−4: coef=0.238210076, firm CR1 SE=0.370631596
- k=−3: coef=-0.296444445, firm CR1 SE=0.234675060
- k=−2: coef=0.261094049, firm CR1 SE=0.208183011
- k=0: coef=-0.030368622, firm CR1 SE=0.129814549
- k=1: coef=0.236050055, firm CR1 SE=0.216594385
- k=2: coef=0.162736712, firm CR1 SE=0.247160438
- k=3: coef=0.155429106, firm CR1 SE=0.215794905
- k=4: coef=0.078683499, firm CR1 SE=0.198870276
- k≥5: coef=0.134567719, firm CR1 SE=0.170151547

Joint pre-treatment categories:
- F(4,9) = 2.5006255100
- p = 0.1166555230

## Few-cluster sensitivities
- Five-of-ten assignments: 252.
- Assignments at least as extreme: 48.
- Reference p = 0.190476190476.
- Restricted firm-level Rademacher patterns: 1024.
- Patterns at least as extreme in absolute t: 180.
- Reference p = 0.175781250000.

These are sensitivity/reference calculations. The teaching assignment was deterministic and is not a documented randomized experiment.

## Separate pre-treatment differential linear trend
Using pre-treatment observations only, firm and period effects, and no contemporaneous controls:
- treated-group differential trend = -0.008371781882
- firm CR1 SE = 0.010174549993
- t(9)-reference p = 0.431872786611
