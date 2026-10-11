# Chapter 13 Editorial Audit

## Completed migration edits

- Retitled the chapter as **Robust Inference and Covariance Estimation for Panel Models**.
- Added a publisher-style abstract.
- Removed all EViews menu, command, workfile, covariance-option, GLS-weight, and `nodf` instructions from the reader-facing chapter.
- Rebuilt the implementation section around R/RStudio.
- Preserved the distinction between coefficient estimation, covariance estimation, and conditional-mean respecification.
- Preserved the HC, one-way cluster, two-way cluster, PCSE, FGLS, and Driscoll-Kraay theory.
- Added native `plm`, `sandwich`, and `clubSandwich` mappings.
- Added CR2/Satterthwaite as a few-cluster sensitivity because only ten firm clusters are available.
- Clarified that `pggls()` changes coefficients and is not directly comparable with covariance-only corrections.
- Replaced EViews references with methodological and R implementation references.
- Replaced applied EViews exercises with R/RStudio exercises.
- Retained the teaching-period disclosure and the original Grunfeld measurement units.

## Interpretation controls

- Robust standard errors are not described as remedies for endogeneity or misspecified conditional means.
- Period clustering and PCSE are not treated as synonyms.
- Driscoll-Kraay is presented as T-asymptotic sensitivity with T=19/20, not as decisive inference.
- Two-way clustering is not described as automatically conservative.
- The negative capital-growth coefficient is reported as statistically uncertain under the cluster methods most directly motivated by Chapter 12.
