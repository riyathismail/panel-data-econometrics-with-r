# Chapter 9 - Fixed Effects: LSDV and the Within Estimator
# Run from the RStudio Project root: source("R/chapter09.R")

required <- c("readr", "dplyr", "tidyr", "plm", "lmtest", "sandwich", "ggplot2", "scales")
missing_pkgs <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs)) {
  stop("Install missing packages in the book renv environment: ", paste(missing_pkgs, collapse = ", "))
}
for (d in c("tables/chapter09", "results/chapter09", "figures/chapter09"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# 1. Import and validate -------------------------------------------------------
dat <- readr::read_csv(
  "data/Grunfeld_PanelData_2006_2025.csv",
  show_col_types = FALSE
) |>
  dplyr::arrange(firm, year) |>
  dplyr::mutate(
    linvest = log(invest),
    lvalue = log(value),
    lcapital = log(capital)
  )
stopifnot(
  nrow(dat) == 200L,
  dplyr::n_distinct(dat$firm) == 10L,
  dplyr::n_distinct(dat$year) == 20L,
  !anyDuplicated(dat[c("firm", "year")]),
  !anyNA(dat[c("invest", "value", "capital")])
)
pdata <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
stopifnot(plm::is.pbalanced(pdata))

# 2. One-way FE three ways ----------------------------------------------------
lsdv <- stats::lm(linvest ~ lvalue + lcapital + factor(firm), data = dat)
within_dat <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    w_linvest = linvest - mean(linvest),
    w_lvalue = lvalue - mean(lvalue),
    w_lcapital = lcapital - mean(lcapital)
  ) |>
  dplyr::ungroup()
within_manual <- stats::lm(w_linvest ~ 0 + w_lvalue + w_lcapital, data = within_dat)
fe_firm <- plm::plm(
  linvest ~ lvalue + lcapital,
  data = pdata,
  model = "within",
  effect = "individual"
)

b_lsdv <- stats::coef(lsdv)[c("lvalue", "lcapital")]
b_manual <- stats::coef(within_manual)
b_plm <- stats::coef(fe_firm)
stopifnot(
  isTRUE(all.equal(unname(b_lsdv), unname(b_manual), tolerance = 1e-10)),
  isTRUE(all.equal(unname(b_lsdv), unname(b_plm), tolerance = 1e-10))
)
expected_fe <- c(lvalue = 0.5918473071, lcapital = 0.2559180164)
stopifnot(max(abs(b_lsdv - expected_fe)) < 1e-9)
stopifnot(abs(stats::deviance(lsdv) - 16.4015397731) < 1e-9)
stopifnot(stats::df.residual(lsdv) == 188L)
stopifnot(abs(summary(lsdv)$r.squared - 0.9605457196) < 1e-9)

within_ss_total <- sum(within_dat$w_linvest^2)
within_r2 <- 1 - stats::deviance(lsdv) / within_ss_total
stopifnot(abs(within_r2 - 0.5644098230) < 1e-9)

# 3. Pooled benchmark and redundant-firm test --------------------------------
pool_lm <- stats::lm(linvest ~ lvalue + lcapital, data = dat)
pool_plm <- plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "pooling")
stopifnot(abs(stats::deviance(pool_lm) - 57.45440268) < 1e-7)
firm_pF <- plm::pFtest(fe_firm, pool_plm)
stopifnot(abs(unname(firm_pF$statistic) - 52.28464544) < 1e-6)

# 4. Normalized one-way firm effects -----------------------------------------
# Cross-check plm's deviation-from-mean normalization with the equivalent LSDV.
firm_effects_plm <- plm::fixef(fe_firm, type = "dmean")
common_intercept_plm <- plm::within_intercept(fe_firm)

firm_levels <- sort(unique(dat$firm))
raw_dummy <- setNames(rep(0, length(firm_levels)), firm_levels)
for (f in firm_levels[-1]) {
  nm <- paste0("factor(firm)", f)
  raw_dummy[as.character(f)] <- stats::coef(lsdv)[nm]
}
common_intercept_lsdv <- unname(stats::coef(lsdv)["(Intercept)"] + mean(raw_dummy))
firm_effects_lsdv <- raw_dummy - mean(raw_dummy)
stopifnot(abs(common_intercept_lsdv - (-0.8469275380)) < 1e-9)
stopifnot(abs(sum(firm_effects_lsdv)) < 1e-12)
stopifnot(abs(min(firm_effects_lsdv) - (-1.1204363213)) < 1e-8)
stopifnot(abs(max(firm_effects_lsdv) - 0.9222836232) < 1e-8)
# plm normalization should agree up to ordering/attributes.
stopifnot(max(abs(as.numeric(firm_effects_plm) - unname(firm_effects_lsdv[names(firm_effects_plm)]))) < 1e-7)
stopifnot(abs(as.numeric(common_intercept_plm) - common_intercept_lsdv) < 1e-7)

# 5. Time-only and two-way FE -------------------------------------------------
fe_time <- plm::plm(
  linvest ~ lvalue + lcapital,
  data = pdata,
  model = "within",
  effect = "time"
)
fe_twoway <- plm::plm(
  linvest ~ lvalue + lcapital,
  data = pdata,
  model = "within",
  effect = "twoways"
)
firm_lsdv <- lsdv
time_lsdv <- stats::lm(linvest ~ lvalue + lcapital + factor(year), data = dat)
twoway_lsdv <- stats::lm(linvest ~ lvalue + lcapital + factor(firm) + factor(year), data = dat)
stopifnot(max(abs(unname(stats::coef(fe_twoway)) - unname(stats::coef(twoway_lsdv)[c("lvalue", "lcapital")]))) < 1e-9)
expected_tw <- c(lvalue = 0.3285541349, lcapital = 0.0767958606)
stopifnot(max(abs(stats::coef(twoway_lsdv)[c("lvalue", "lcapital")] - expected_tw)) < 1e-9)
stopifnot(abs(stats::deviance(twoway_lsdv) - 8.8794497289) < 1e-9)
stopifnot(stats::df.residual(twoway_lsdv) == 169L)

nested_f <- function(restricted, unrestricted) {
  q <- stats::df.residual(restricted) - stats::df.residual(unrestricted)
  df2 <- stats::df.residual(unrestricted)
  fstat <- ((stats::deviance(restricted) - stats::deviance(unrestricted)) / q) /
    (stats::deviance(unrestricted) / df2)
  pval <- stats::pf(fstat, q, df2, lower.tail = FALSE)
  data.frame(df1 = q, df2 = df2, statistic = fstat, p.value = pval)
}
T_firm_pool <- nested_f(pool_lm, firm_lsdv)
T_time_pool <- nested_f(pool_lm, time_lsdv)
T_period_given_firm <- nested_f(firm_lsdv, twoway_lsdv)
T_firm_given_period <- nested_f(time_lsdv, twoway_lsdv)
T_joint <- nested_f(pool_lm, twoway_lsdv)
stopifnot(
  abs(T_firm_pool$statistic - 52.28464544) < 1e-6,
  abs(T_time_pool$statistic - 0.8674858564) < 1e-6,
  abs(T_period_given_firm$statistic - 7.5350402884) < 1e-6,
  abs(T_firm_given_period$statistic - 92.4265092616) < 1e-6,
  abs(T_joint$statistic - 33.0183227998) < 1e-6
)

effect_tests <- dplyr::bind_rows(
  cbind(test = "Firm effects vs pooled", T_firm_pool),
  cbind(test = "Period effects vs pooled", T_time_pool),
  cbind(test = "Period effects | firm effects", T_period_given_firm),
  cbind(test = "Firm effects | period effects", T_firm_given_period),
  cbind(test = "Joint firm + period effects", T_joint)
)

# 6. Two-way normalized period effects ---------------------------------------
year_levels <- sort(unique(dat$year))
raw_year <- setNames(rep(0, length(year_levels)), year_levels)
for (y in year_levels[-1]) {
  nm <- paste0("factor(year)", y)
  raw_year[as.character(y)] <- stats::coef(twoway_lsdv)[nm]
}
period_effects <- raw_year - mean(raw_year)
stopifnot(abs(sum(period_effects)) < 1e-12)

# 7. Covariance sensitivity on the equivalent LSDV model ---------------------
V_firm <- sandwich::vcovCL(lsdv, cluster = dat$firm, type = "HC1", cadjust = TRUE)
V_period <- sandwich::vcovCL(lsdv, cluster = dat$year, type = "HC1", cadjust = TRUE)
V_twoway <- sandwich::vcovCL(lsdv, cluster = dat[c("firm", "year")], type = "HC1", cadjust = TRUE)

slope_idx <- match(c("lvalue", "lcapital"), names(stats::coef(lsdv)))
se_conv <- sqrt(diag(stats::vcov(lsdv)))[slope_idx]
se_firm <- sqrt(diag(V_firm))[slope_idx]
se_period <- sqrt(diag(V_period))[slope_idx]
se_twoway <- sqrt(diag(V_twoway))[slope_idx]
stopifnot(max(abs(se_conv - c(0.08823668, 0.02670224))) < 1e-7)
stopifnot(max(abs(se_firm - c(0.13008275, 0.07042436))) < 1e-7)
stopifnot(max(abs(se_period - c(0.05647732, 0.05305235))) < 1e-7)
stopifnot(max(abs(se_twoway - c(0.11180064, 0.07509674))) < 1e-7)

cov_row <- function(label, se, dfref) {
  b <- b_lsdv
  tval <- b / se
  pval <- 2 * stats::pt(abs(tval), df = dfref, lower.tail = FALSE)
  data.frame(covariance = label, term = names(b), estimate = unname(b),
             std.error = unname(se), statistic = unname(tval),
             p.value = unname(pval), df.reference = dfref)
}
cov_table <- dplyr::bind_rows(
  cov_row("Conventional", se_conv, 188),
  cov_row("Firm cluster", se_firm, 9),
  cov_row("Period cluster", se_period, 19),
  cov_row("Two-way cluster", se_twoway, 9)
)

# 8. Descriptive residual persistence ----------------------------------------
dw_stacked <- function(model) {
  e <- stats::residuals(model)
  sum(diff(e)^2) / sum(e^2)
}
dw_pool <- dw_stacked(pool_lm)
dw_firm <- dw_stacked(firm_lsdv)
dw_twoway <- dw_stacked(twoway_lsdv)
stopifnot(abs(dw_pool - 0.3606489547) < 1e-9)
stopifnot(abs(dw_firm - 0.80012040) < 1e-7)
stopifnot(abs(dw_twoway - 0.92242490) < 1e-7)

# 9. First-difference bridge --------------------------------------------------
short <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    dlinvest = linvest - dplyr::lag(linvest),
    dlvalue = lvalue - dplyr::lag(lvalue),
    dlcapital = lcapital - dplyr::lag(lcapital)
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
stopifnot(nrow(short) == 190L)
fd_base <- stats::lm(dlinvest ~ dlvalue + dlcapital, data = short)
fd_firm <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(firm), data = short)
fd_period <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data = short)
T_fd_firm <- nested_f(fd_base, fd_firm)
T_fd_period <- nested_f(fd_base, fd_period)
stopifnot(abs(T_fd_firm$statistic - 0.19407415) < 2e-5)
stopifnot(abs(T_fd_period$statistic - 4.84494697) < 2e-5)

# 10. Export tables -----------------------------------------------------------
write.csv(as.data.frame(coef(summary(lsdv))), "tables/chapter09/lsdv_coefficients.csv")
write.csv(data.frame(term = names(b_manual), estimate = unname(b_manual)),
          "tables/chapter09/manual_within_coefficients.csv", row.names = FALSE)
write.csv(data.frame(term = names(b_plm), estimate = unname(b_plm)),
          "tables/chapter09/plm_within_coefficients.csv", row.names = FALSE)
write.csv(data.frame(firm = as.integer(names(firm_effects_lsdv)), effect = unname(firm_effects_lsdv)),
          "tables/chapter09/firm_effects_sum_zero.csv", row.names = FALSE)
write.csv(data.frame(year = as.integer(names(period_effects)), effect = unname(period_effects)),
          "tables/chapter09/period_effects_sum_zero.csv", row.names = FALSE)
write.csv(effect_tests, "tables/chapter09/effect_tests.csv", row.names = FALSE)
write.csv(cov_table, "tables/chapter09/covariance_sensitivity.csv", row.names = FALSE)
write.csv(data.frame(model = c("Pooled", "Firm FE", "Two-way FE"),
                     stacked_DW = c(dw_pool, dw_firm, dw_twoway)),
          "results/chapter09/stacked_dw_descriptive.csv", row.names = FALSE)

# 11. Figures -----------------------------------------------------------------
# Conceptual within transformation for lvalue by firm.
plot_within <- within_dat |>
  dplyr::filter(firm %in% c(1, 2, 3)) |>
  dplyr::select(firm, year, lvalue, w_lvalue)
p1 <- ggplot2::ggplot(plot_within, ggplot2::aes(year, lvalue, group = factor(firm), linetype = factor(firm))) +
  ggplot2::geom_line(linewidth = 0.6) +
  ggplot2::labs(x = "Teaching-period label", y = "log(value)", linetype = "Firm") +
  ggplot2::theme_minimal(base_size = 10)
p1b <- ggplot2::ggplot(plot_within, ggplot2::aes(year, w_lvalue, group = factor(firm), linetype = factor(firm))) +
  ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) + ggplot2::geom_line(linewidth = 0.6) +
  ggplot2::labs(x = "Teaching-period label", y = "Within-firm log(value)", linetype = "Firm") +
  ggplot2::theme_minimal(base_size = 10)
# Save the transformed panel alone under the manuscript name to avoid another assembly dependency.
ggplot2::ggsave("figures/chapter09/within_transformation.pdf", p1b, width = 7, height = 4.2)

p2 <- ggplot2::ggplot(within_dat, ggplot2::aes(w_lvalue, w_linvest)) +
  ggplot2::geom_point(size = 1.1, alpha = 0.7) +
  ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE, linewidth = 0.6) +
  ggplot2::labs(x = "Demeaned log(value)", y = "Demeaned log(invest)") +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter09/within_scatter.pdf", p2, width = 7, height = 4.2)

firm_eff_df <- data.frame(firm = factor(names(firm_effects_lsdv), levels = names(firm_effects_lsdv)), effect = unname(firm_effects_lsdv))
p3 <- ggplot2::ggplot(firm_eff_df, ggplot2::aes(firm, effect)) +
  ggplot2::geom_col() + ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) +
  ggplot2::labs(x = "Firm", y = "Normalized firm effect") + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter09/firm_effects.pdf", p3, width = 7, height = 4)

coef_models <- data.frame(
  model = rep(c("Pooled", "Firm FE", "Two-way FE"), each = 2),
  regressor = rep(c("log(value)", "log(capital)"), 3),
  estimate = c(coef(pool_lm)["lvalue"], coef(pool_lm)["lcapital"],
               b_lsdv["lvalue"], b_lsdv["lcapital"],
               coef(twoway_lsdv)["lvalue"], coef(twoway_lsdv)["lcapital"])
)
p4 <- ggplot2::ggplot(coef_models, ggplot2::aes(model, estimate, group = regressor, shape = regressor)) +
  ggplot2::geom_point(size = 2.5) + ggplot2::geom_line(ggplot2::aes(linetype = regressor)) +
  ggplot2::labs(x = NULL, y = "Estimated elasticity", shape = NULL, linetype = NULL) + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter09/coefficient_models.pdf", p4, width = 7, height = 4)

period_df <- data.frame(year = as.integer(names(period_effects)), effect = unname(period_effects))
p5 <- ggplot2::ggplot(period_df, ggplot2::aes(year, effect)) +
  ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) + ggplot2::geom_line(linewidth = 0.6) + ggplot2::geom_point(size = 1.3) +
  ggplot2::labs(x = "Teaching-period label", y = "Normalized period effect") + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter09/period_effects.pdf", p5, width = 7, height = 4)

fit_df <- data.frame(model = c("Pooled", "Firm FE", "Two-way FE"),
                     overall_R2 = c(summary(pool_lm)$r.squared, summary(lsdv)$r.squared, summary(twoway_lsdv)$r.squared),
                     stacked_DW = c(dw_pool, dw_firm, dw_twoway))
fit_long <- tidyr::pivot_longer(fit_df, c(overall_R2, stacked_DW), names_to = "metric", values_to = "value")
p6 <- ggplot2::ggplot(fit_long, ggplot2::aes(model, value, fill = metric)) +
  ggplot2::geom_col(position = "dodge") + ggplot2::labs(x = NULL, y = "Value", fill = NULL) + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter09/fit_persistence.pdf", p6, width = 7, height = 4)

eff_plot <- dplyr::bind_rows(
  data.frame(test = "Firm effects\nlogged levels", p = T_firm_pool$p.value),
  data.frame(test = "Period effects | firms\nlogged levels", p = T_period_given_firm$p.value),
  data.frame(test = "Firm effects\nafter FD", p = T_fd_firm$p.value),
  data.frame(test = "Period effects\nafter FD", p = T_fd_period$p.value)
) |>
  dplyr::mutate(evidence = -log10(p))
p7 <- ggplot2::ggplot(eff_plot, ggplot2::aes(test, evidence)) +
  ggplot2::geom_col() + ggplot2::geom_hline(yintercept = -log10(0.05), linetype = 2) +
  ggplot2::labs(x = NULL, y = expression(-log[10](p))) +
  ggplot2::theme_minimal(base_size = 9) + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 15, hjust = 1))
ggplot2::ggsave("figures/chapter09/effects_tests.pdf", p7, width = 7, height = 4.2)

# Covariance figure is an additional reproducibility output even though the manuscript table carries the exact values.
cov_plot <- cov_table |>
  dplyr::filter(term %in% c("lvalue", "lcapital"))
p8 <- ggplot2::ggplot(cov_plot, ggplot2::aes(covariance, std.error, group = term, shape = term)) +
  ggplot2::geom_point(size = 2.2) + ggplot2::geom_line() +
  ggplot2::labs(x = NULL, y = "Standard error", shape = NULL) +
  ggplot2::theme_minimal(base_size = 9) + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 25, hjust = 1))
ggplot2::ggsave("figures/chapter09/fe_covariance_sensitivity.pdf", p8, width = 7, height = 4)

writeLines(capture.output(sessionInfo()), "results/chapter09/sessionInfo.txt")
message("Chapter 9 FE benchmark reproduced successfully by LSDV, manual within, and plm within estimators.")
