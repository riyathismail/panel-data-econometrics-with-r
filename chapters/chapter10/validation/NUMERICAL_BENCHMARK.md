# Chapter 10 Numerical Benchmark

Independent reconstruction from the authoritative Grunfeld teaching CSV. The final R release gate still requires live execution of `R/chapter10.R`.

## One-way logged-level Swamy--Arora reconstruction

- Within/FE residual variance: **0.087242232836**
- Between residual variance: **0.253927728225**
- Firm variance: **0.249565616583**
- Conditional ICC: **0.740973279018**
- Quasi-demeaning parameter: **0.868933010359**
- Random-effect shrinkage factor: **0.982821444226**

## Manual quasi-demeaned GLS coefficients

- Intercept: **-1.288351711489**
- `lvalue`: **0.662453320092**
- `lcapital`: **0.255515457857**
- Conventional SEs: **0.463555083050, 0.075447761504, 0.026117236760**

## Pooled-vs-random-component LM evidence

- BP ratio term: **12.974177235896**
- Breusch-Pagan LM: **754.636423561308**
- Signed Honda-style score: **27.470646580692**

## Predicted random effects

- Largest positive: firm **2**, **0.816771266**
- Largest negative: firm **10**, **-0.961857675**

## Growth boundary case

- Growth idiosyncratic variance: **0.056124482802**
- Raw growth firm variance estimate: **-0.002586688116**
- Constrained growth firm variance: **0**
- Growth theta: **0**
- Growth BP LM: **3.562023175631**
- Growth Honda score: **-1.887332290730**

## Covariance sensitivity

| Covariance | SE lvalue | p lvalue | SE lcapital | p lcapital |
|---|---:|---:|---:|---:|
| Conventional | 0.075447762 | 7.87194e-16 | 0.026117237 | 1.12876e-18 |
| HC1 | 0.084813056 | 3.30818e-13 | 0.047286150 | 1.87358e-07 |
| Firm cluster | 0.116015746 | 0.000290596 | 0.069916932 | 0.00527998 |
| Period cluster | 0.053721599 | 1.63356e-10 | 0.059752113 | 0.000407856 |
| Two-way cluster | 0.095668224 | 6.8768e-05 | 0.078884170 | 0.0101729 |

## Status

- Data/analytical reconstruction: **PASS**
- Manual quasi-demeaning benchmark: **PASS**
- LM and shrinkage benchmark: **PASS**
- R live execution / `renv.lock`: **PENDING** because the current migration runtime has no R interpreter.
