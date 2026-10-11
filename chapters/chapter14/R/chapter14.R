# Chapter 14 - Statistical Interpretation and Reporting
# Run from project root: source("R/chapter14.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "modelsummary")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter14", "results/chapter14", "figures/chapter14"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest = log(invest), lvalue = log(value), lcapital = log(capital),
    dlinvest = linvest - dplyr::lag(linvest),
    dlvalue = lvalue - dplyr::lag(lvalue),
    dlcapital = lcapital - dplyr::lag(lcapital)
  ) |>
  dplyr::ungroup()
short <- dat |> dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
stopifnot(nrow(dat) == 200L, nrow(short) == 190L,
          dplyr::n_distinct(short$firm) == 10L, dplyr::n_distinct(short$year) == 19L)

primary_model <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data = short)
stopifnot(abs(coef(primary_model)["dlvalue"] - 0.495709423973) < 1e-10)
stopifnot(abs(coef(primary_model)["dlcapital"] - (-0.0856926114420)) < 1e-10)
stopifnot(abs(summary(primary_model)$r.squared - 0.492530736506) < 1e-10)
stopifnot(abs(summary(primary_model)$adj.r.squared - 0.432475202364) < 1e-10)
stopifnot(stats::df.residual(primary_model) == 169L)

# Explicit CR1 covariance convention used throughout Chapters 13-14.
vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X))
  correction <- (G / (G - 1)) * ((n - 1) / (n - k))
  correction * bread %*% crossprod(S) %*% bread
}
vcov_2way_cr1 <- function(model, c1, c2) {
  vcov_cr1(model, c1) + vcov_cr1(model, c2) -
    vcov_cr1(model, interaction(c1, c2, drop = TRUE))
}
V_firm <- vcov_cr1(primary_model, short$firm)
V_period <- vcov_cr1(primary_model, short$year)
V_2way <- vcov_2way_cr1(primary_model, short$firm, short$year)

report_terms <- function(model, V, df_ref, label) {
  b <- stats::coef(model); se <- sqrt(diag(V)); keep <- c("dlvalue", "dlcapital")
  tval <- b[keep] / se[keep]; crit <- stats::qt(.975, df_ref)
  data.frame(
    covariance = label,
    term = keep,
    estimate = unname(b[keep]),
    std.error = unname(se[keep]),
    statistic = unname(tval),
    p.value = 2 * stats::pt(abs(tval), df = df_ref, lower.tail = FALSE),
    conf.low = unname(b[keep] - crit * se[keep]),
    conf.high = unname(b[keep] + crit * se[keep]),
    df.reference = df_ref,
    row.names = NULL
  )
}
firm_report <- report_terms(primary_model, V_firm, 9, "Firm cluster")
period_report <- report_terms(primary_model, V_period, 18, "Period cluster")
twoway_report <- report_terms(primary_model, V_2way, 9, "Two-way cluster")
report_all <- dplyr::bind_rows(firm_report, period_report, twoway_report)

# Published benchmark assertions.
bench <- data.frame(
  covariance = rep(c("Firm cluster", "Period cluster", "Two-way cluster"), each = 2),
  term = rep(c("dlvalue", "dlcapital"), 3),
  se = c(0.138414508506, 0.0401240022053,
         0.0743364623111, 0.0419266496362,
         0.120338033149, 0.0412292913853),
  p = c(0.005918340220, 0.061449967524,
        0.00000295237821, 0.055881489194,
        0.0026006260265, 0.067435464153),
  lo = c(0.182594052121, -0.176459410431,
         0.339534311910, -0.173777233736,
         0.223485880327, -0.178959748266),
  hi = c(0.808824795824, 0.005074187547,
         0.651884536036, 0.002392010852,
         0.767932967618, 0.007574525382)
)
check <- merge(report_all, bench, by = c("covariance", "term"), sort = FALSE)
stopifnot(max(abs(check$std.error - check$se)) < 1e-10,
          max(abs(check$p.value - check$p)) < 1e-10,
          max(abs(check$conf.low - check$lo)) < 1e-10,
          max(abs(check$conf.high - check$hi)) < 1e-10)

# Exact log-log finite-change conversions.
exact_log_change <- function(beta, x_pct) 100 * ((1 + x_pct / 100)^beta - 1)
value_period <- period_report[period_report$term == "dlvalue", ]
capital_period <- period_report[period_report$term == "dlcapital", ]
changes <- c(1, 5, 10, 20)
finite_value <- data.frame(
  regressor.change.pct = changes,
  approximation.pct = 100 * value_period$estimate * changes / 100,
  exact.pct = vapply(changes, function(x) exact_log_change(value_period$estimate, x), numeric(1)),
  exact.low.pct = vapply(changes, function(x) exact_log_change(value_period$conf.low, x), numeric(1)),
  exact.high.pct = vapply(changes, function(x) exact_log_change(value_period$conf.high, x), numeric(1))
)
stopifnot(abs(finite_value$exact.pct[finite_value$regressor.change.pct == 10] - 4.83800406066) < 1e-9)
capital10 <- data.frame(
  regressor.change.pct = 10,
  exact.pct = exact_log_change(capital_period$estimate, 10),
  exact.low.pct = exact_log_change(capital_period$conf.low, 10),
  exact.high.pct = exact_log_change(capital_period$conf.high, 10)
)
stopifnot(abs(capital10$exact.pct - (-0.813411578825)) < 1e-9)

# Machine-readable exports.
utils::write.csv(report_all, "tables/chapter14/cluster_sensitivity.csv", row.names = FALSE)
utils::write.csv(finite_value, "tables/chapter14/exact_value_conversions.csv", row.names = FALSE)
utils::write.csv(capital10, "tables/chapter14/exact_capital_conversion.csv", row.names = FALSE)

# Compact manuscript table: build from verified statistics, then style/export.
fmt_ci <- function(lo, hi) sprintf("[%.4f, %.4f]", lo, hi)
make_compact_reporting_table <- function(period_report, twoway_report, model,
                                         n_firms, n_periods) {
  pv <- period_report[period_report$term == "dlvalue", ]
  pc <- period_report[period_report$term == "dlcapital", ]
  tv <- twoway_report[twoway_report$term == "dlvalue", ]
  tc <- twoway_report[twoway_report$term == "dlcapital", ]
  data.frame(
    Item = c("Delta log(value): estimate", "Standard error", "95% confidence interval",
             "Delta log(capital): estimate", "Standard error", "95% confidence interval",
             "Period effects", "Observations", "Firms", "Transition periods", "R-squared", "Adjusted R-squared"),
    `Period clustered` = c(
      sprintf("%.4f", pv$estimate), sprintf("%.4f", pv$std.error), fmt_ci(pv$conf.low, pv$conf.high),
      sprintf("%.4f", pc$estimate), sprintf("%.4f", pc$std.error), fmt_ci(pc$conf.low, pc$conf.high),
      "Yes", as.character(stats::nobs(model)), as.character(n_firms), as.character(n_periods),
      sprintf("%.4f", summary(model)$r.squared), sprintf("%.4f", summary(model)$adj.r.squared)
    ),
    `Two-way clustered` = c(
      sprintf("%.4f", tv$estimate), sprintf("%.4f", tv$std.error), fmt_ci(tv$conf.low, tv$conf.high),
      sprintf("%.4f", tc$estimate), sprintf("%.4f", tc$std.error), fmt_ci(tc$conf.low, tc$conf.high),
      "Yes", as.character(stats::nobs(model)), as.character(n_firms), as.character(n_periods),
      sprintf("%.4f", summary(model)$r.squared), sprintf("%.4f", summary(model)$adj.r.squared)
    ), check.names = FALSE
  )
}
compact <- make_compact_reporting_table(period_report, twoway_report, primary_model, 10L, 19L)
utils::write.csv(compact, "tables/chapter14/primary_reporting_table.csv", row.names = FALSE)
modelsummary::datasummary_df(
  compact,
  output = "tables/chapter14/primary_reporting_table.tex",
  fmt = 4,
  title = "Primary short-run panel-regression result"
)
modelsummary::datasummary_df(
  compact,
  output = "tables/chapter14/primary_reporting_table.md",
  fmt = 4,
  title = "Primary short-run panel-regression result"
)

# Figures ---------------------------------------------------------------------
# Evidence chain.
chain <- data.frame(
  x = 1:6, y = 1,
  label = c("Research question", "Admissible stochastic form", "Estimator / effects", "Diagnostics", "Covariance", "Interpretation / limits")
)
p_chain <- ggplot2::ggplot(chain, ggplot2::aes(x, y, label = label)) +
  ggplot2::geom_label(size = 3.0, label.size = 0.25) +
  ggplot2::geom_segment(data = data.frame(x = 1:5, xend = 2:6),
                        ggplot2::aes(x = x, xend = xend, y = 1, yend = 1),
                        inherit.aes = FALSE,
                        arrow = grid::arrow(length = grid::unit(0.09, "in")), linewidth = 0.35) +
  ggplot2::coord_cartesian(xlim = c(.6, 6.4), ylim = c(.7, 1.3)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter14/evidence_chain.pdf", p_chain, width = 7.2, height = 2.1)

# Approximate vs exact finite change.
exact_plot <- finite_value |>
  tidyr::pivot_longer(c(approximation.pct, exact.pct), names_to = "method", values_to = "investment.change.pct")
p_exact <- ggplot2::ggplot(exact_plot, ggplot2::aes(regressor.change.pct, investment.change.pct, linetype = method)) +
  ggplot2::geom_line(linewidth = 0.7) + ggplot2::geom_point(size = 1.7) +
  ggplot2::labs(x = "Firm-value change (%)", y = "Estimated investment change (%)", linetype = NULL) +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter14/exact_vs_approx.pdf", p_exact, width = 6.7, height = 3.8)

# Confidence intervals.
ci_plot <- dplyr::bind_rows(period_report, twoway_report) |>
  dplyr::mutate(term = dplyr::recode(term, dlvalue = "Delta log(value)", dlcapital = "Delta log(capital)"))
p_ci <- ggplot2::ggplot(ci_plot, ggplot2::aes(estimate, term, xmin = conf.low, xmax = conf.high, shape = covariance)) +
  ggplot2::geom_vline(xintercept = 0, linewidth = 0.35) +
  ggplot2::geom_pointrange(position = ggplot2::position_dodge(width = .35)) +
  ggplot2::labs(x = "Coefficient and 95% cluster-reference interval", y = NULL, shape = NULL) + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter14/primary_ci.pdf", p_ci, width = 6.8, height = 3.6)

# Reporting architecture.
arch <- data.frame(
  x = c(1,2,3,1,2,3), y = c(2,2,2,1,1,1),
  label = c("Model identity", "Coefficient magnitude", "Uncertainty", "Diagnostics", "Robustness", "Limitations")
)
p_arch <- ggplot2::ggplot(arch, ggplot2::aes(x, y, label = label)) +
  ggplot2::geom_label(size = 3.4, label.size = .3) +
  ggplot2::coord_cartesian(xlim = c(.5,3.5), ylim = c(.55,2.45)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter14/reporting_architecture.pdf", p_arch, width = 6.8, height = 3.5)

writeLines(capture.output(sessionInfo()), "results/chapter14/sessionInfo.txt")
message("Chapter 14 reporting benchmark reproduced and exported.")
