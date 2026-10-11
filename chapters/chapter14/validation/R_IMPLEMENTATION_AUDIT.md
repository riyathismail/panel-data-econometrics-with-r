# Chapter 14 R Implementation Audit

## Architecture

Chapter 14 separates statistical computation from publisher formatting.

1. Import and validate the raw teaching CSV.
2. Construct logs and within-firm first log differences.
3. Estimate the period-effects short-run model with `lm()`.
4. Build explicit CR1 firm, period, and two-way covariance matrices.
5. Construct cluster-reference `t`, `p`, and confidence intervals with stated reference degrees of freedom.
6. Assert all published benchmark values.
7. Calculate exact finite percentage changes from coefficient and interval endpoints.
8. Save machine-readable CSV tables.
9. Pass verified reporting data frames to `modelsummary::datasummary_df()` for LaTeX and Markdown export.
10. Generate reporting figures and capture `sessionInfo()`.

## Why the table package is downstream

`modelsummary` can accept robust covariance matrices and supports confidence-interval and multi-format output. However, Chapter 14 uses an explicit `t_(G-1)` reporting convention for the cluster tables. The script therefore calculates those inferential quantities directly before formatting. This avoids allowing a table package or model-extraction backend to silently select a different reference distribution.

## Package roles

- `readr`: raw CSV import.
- `dplyr` / `tidyr`: panel-safe transformations and reporting data frames.
- `ggplot2`: publication figures.
- `modelsummary`: publication-table rendering/export from verified data frames.

## Live execution status

The current migration container does not contain an R interpreter. Source construction, independent numerical validation, and LaTeX integration are complete. Actual R execution, package-version capture, generated `.tex`/`.md` tables, and `renv.lock` remain pending.
