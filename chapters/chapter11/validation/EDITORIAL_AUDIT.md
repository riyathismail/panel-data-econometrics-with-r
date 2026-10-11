# Chapter 11 Editorial Audit

## Completed migration edits

- Reframed the chapter as **Choosing Among Pooled OLS, Fixed Effects, and Random Effects**.
- Added a publisher-style abstract.
- Preserved the three logically distinct selection questions and their null hypotheses.
- Replaced all EViews menu paths, commands, equation objects, and workfile instructions with R/RStudio code.
- Added `pFtest()`, `plmtest()`, and `phtest()` workflows using matched model specifications.
- Added an explicit warning that the conventional quadratic-form Hausman test should not be robustified by arbitrary covariance substitution.
- Added the regression-based auxiliary Hausman option as a sensitivity check.
- Retained and strengthened the period-adjusted Mundlak/CRE specification as the robust correlated-effects diagnostic.
- Kept model-form selection, effect selection, and covariance selection conceptually separate.
- Replaced the EViews exercises with R/RStudio exercises.
- Replaced EViews documentation references with R/`plm` documentation references.
- Preserved the teaching-period disclaimer: 2006-2025 are labels mapped to the original Grunfeld 1935-1954 sequence.

## Interpretive safeguards

- Rejecting pooled OLS does not by itself choose FE or RE.
- A significant LM test detects a nonzero random component, not RE orthogonality.
- A significant Hausman test provides evidence against the maintained conventional RE restrictions; it does not prove FE is causal or universally correct.
- A non-significant Hausman test is non-rejection, not proof of zero correlation.
- An indefinite covariance-difference matrix is a failed conventional comparison, not evidence for RE.
- The logged-level and first-log-difference specifications are different estimands and may select different effect structures without contradiction.
