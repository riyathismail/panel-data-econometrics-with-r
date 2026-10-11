# Panel Data Econometrics with R — companion scripts and teaching data

Author: Dr. M.I.M. Riyath. Prepared for https://github.com/riyathismail.

## Download

[Download the verified companion ZIP](https://github.com/riyathismail/panel-data-econometrics-with-r/releases/download/v1.0.0/Panel_Data_Econometrics_with_R_Companion.zip)
or visit the [latest release](https://github.com/riyathismail/panel-data-econometrics-with-r/releases/latest).
The release also provides a SHA-256 checksum. This public repository contains
the same verified scripts and datasets for browsing by chapter.

Each chapter is an independent RStudio project. Open its folder, restore
dependencies with `source("restore_environment.R")`, then execute
`source("R/chapterXX.R")`, replacing XX with the chapter number. R 4.5.2 is
the tested release. Dependency installation requires internet access.
Do not run the scripts from the repository root.

Chapters 15 and 24 additionally include complete `targets` workflows. Run
`source("run_chapter15.R")` or `source("run_chapter24.R")` inside that chapter.
Both workflows and the Chapter 24 tests were executed successfully.
The frozen dependency files now include the workflow dependencies.

## Verification scope

All 24 principal scripts were tested from a fresh extraction without saved
tables or results. Independent calculations checked raw data identity,
fixed-effects algebra, capstone period-clustered standard errors, Chapter 4's
ADF/Fisher table, and Chapter 17's Engle-Granger statistics and probabilities.
Changes were retested; the final archive has a separate fresh-extraction run.
Execution logs and numerical assertions are supplied. Passing these checks
does not certify every theoretical statement or every optional estimator.

Chapters 4, 15, 17 and 24 additionally passed dependency restoration into
empty libraries and execution without personal R packages. Both complete
targets workflows also ran using restored dependencies and new target stores.
All 24 environments have recorded versions; restoring each of the other
20 environments separately has not been tested.

Chapter 17 now constructs its equilibrium error from the long-run slopes and
deterministic effects, excluding DOLS difference controls. The corrected
adjustment coefficient is -0.403745405145; its conditional half-life is
approximately 1.34048 periods. The book's case equation and inference table
were updated together. Its cointegration figure uses newly calculated R
probabilities rather than copied results. Asymptotic probabilities and
finite-sample critical values differ in this short sample; firm 7 is borderline.

Post-period-effect CD statistics are descriptive. Ordinary CD p-values are
not calibrated after fitting complete period effects and are not used to
claim remaining dependence. Conservative covariance choices remain sensitivities.
The Chapter 23 manual logit covariance was compared with sandwich::vcovCL;
the relevant two-coefficient covariance block has positive eigenvalues.
Full two-way covariance matrices can have negative nuisance diagonals; no
undisclosed positive-definiteness repair is applied.

## Known estimator limits

The optional Chapter 16 GMM attempt fails with a singular matrix for this
10-firm dataset. Setting RUN_CH16_GMM=1 records that failure and continues
the supported OLS/IV calculations. It does not produce a validated GMM estimate.
PMG in Chapter 20 is the stated transparent homoskedastic profile-NLS teaching
reconstruction; it is not a verified general PSS-PMG package implementation.
Optional external estimators remain outside this release's verification.

Numerical checks allow small optimizer differences where documented. Core
sample counts and capstone coefficient/standard-error checks remain strict.

## Data provenance and third-party material

The values match the original Grunfeld panel in the plm package. Original
years 1935–1954 are deliberately labelled 2006–2025 for teaching; these are
not contemporary observations. Binary outcomes and treatment examples are
teaching constructions, not observed policy experiments.

Each chapter supplies its data provenance and hashes. The response-surface
coefficients used in Chapters 4 and 17 come from statsmodels 0.14.5; its BSD
license is included in their reproducibility folders. Consult the original
data and package sources for applicable terms. No new blanket open-source
license is assigned to the author's original materials in this release.

The companion supplies scripts, datasets and selected outputs. The book
manuscript and LaTeX build are distributed separately. SHA256SUMS.txt verifies
the distributed contents. Do not replace the release lockfiles with a snapshot
of an unrelated local environment.
