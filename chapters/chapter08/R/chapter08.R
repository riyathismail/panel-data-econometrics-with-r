# Chapter 8 - The First-Difference Estimator
# Run from the RStudio Project root: source("R/chapter08.R")

required <- c("readr", "dplyr", "tidyr", "plm", "lmtest", "sandwich", "ggplot2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in the renv environment: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter08", "results/chapter08", "figures/chapter08"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year)
stopifnot(
  nrow(dat) == 200L,
  dplyr::n_distinct(dat$firm) == 10L,
  dplyr::n_distinct(dat$year) == 20L,
  !anyDuplicated(dat[c("firm", "year")]),
  !anyNA(dat[c("invest", "value", "capital")]),
  all(dat$invest > 0), all(dat$value > 0), all(dat$capital > 0)
)

pdata_level <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
stopifnot(plm::is.pbalanced(pdata_level))

# Panel-safe transformations --------------------------------------------------
dat <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest = log(invest),
    lvalue = log(value),
    lcapital = log(capital),
    dlinvest = linvest - dplyr::lag(linvest),
    dlvalue = lvalue - dplyr::lag(lvalue),
    dlcapital = lcapital - dplyr::lag(lcapital),
    dinvest_level = invest - dplyr::lag(invest),
    dvalue_level = value - dplyr::lag(value),
    dcapital_level = capital - dplyr::lag(capital)
  ) |>
  dplyr::ungroup()

short <- dat |>
  dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
stopifnot(nrow(short) == 190L)
stopifnot(all(is.na(dat$dlinvest[dat$year == min(dat$year)])))
stopifnot(abs(mean(short$dlinvest) - 0.065406) < 1e-6)
stopifnot(abs(mean(short$dlvalue) - 0.038198) < 1e-6)
stopifnot(abs(mean(short$dlcapital) - 0.151537) < 1e-6)

# Manual first differences versus plm(model = "fd") -------------------------
fd_manual <- stats::lm(dlinvest ~ dlvalue + dlcapital, data = short)
pdata_log <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
fd_plm <- plm::plm(linvest ~ lvalue + lcapital, data = pdata_log, model = "fd")
stopifnot(stats::nobs(fd_plm) == 190L)
stopifnot(isTRUE(all.equal(unname(coef(fd_manual)), unname(coef(fd_plm)), tolerance = 1e-10)))

expected_fd <- c(`(Intercept)` = 0.0543445427812,
                 dlvalue = 0.5788460171789,
                 dlcapital = -0.0729165580731)
stopifnot(max(abs(coef(fd_manual) - expected_fd)) < 1e-9)
stopifnot(abs(summary(fd_manual)$r.squared - 0.230661445887) < 1e-10)
stopifnot(abs(summary(fd_manual)$adj.r.squared - 0.222433226057) < 1e-10)

# Covariance sensitivity ------------------------------------------------------
vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  meat <- crossprod(S); bread <- solve(crossprod(X))
  correction <- (G / (G - 1)) * ((n - 1) / (n - k))
  correction * bread %*% meat %*% bread
}
vcov_hc1_manual <- function(model) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); bread <- solve(crossprod(X))
  meat <- crossprod(X, X * e^2)
  (n / (n - k)) * bread %*% meat %*% bread
}
vcov_2way_cr1 <- function(model, c1, c2) {
  vcov_cr1(model, c1) + vcov_cr1(model, c2) -
    vcov_cr1(model, interaction(c1, c2, drop = TRUE))
}
V_ordinary <- stats::vcov(fd_manual)
V_hc1 <- vcov_hc1_manual(fd_manual)
V_firm <- vcov_cr1(fd_manual, short$firm)
V_period <- vcov_cr1(fd_manual, short$year)
V_2way <- vcov_2way_cr1(fd_manual, short$firm, short$year)
stopifnot(isTRUE(all.equal(V_hc1, sandwich::vcovHC(fd_manual, type = "HC1"), tolerance = 1e-10)))

cov_se <- rbind(
  Ordinary = sqrt(diag(V_ordinary)),
  HC1 = sqrt(diag(V_hc1)),
  `Firm cluster` = sqrt(diag(V_firm)),
  `Period cluster` = sqrt(diag(V_period)),
  `Two-way cluster` = sqrt(diag(V_2way))
)
expected_se <- rbind(
  c(0.0188210605843, 0.0796604272785, 0.0505641140239),
  c(0.0188500876049, 0.0644621344747, 0.0383104788971),
  c(0.00755291916237, 0.0698694463721, 0.0304145258730),
  c(0.0335453231123, 0.104738569655, 0.0422459290164),
  c(0.0287577726514, 0.108150546594, 0.0352430008543)
)
stopifnot(max(abs(unname(cov_se) - expected_se)) < 1e-9)

# Package covariance calls retained as implementation cross-checks.
V_firm_pkg <- sandwich::vcovCL(fd_manual, cluster = short$firm, type = "HC1", cadjust = TRUE)
V_period_pkg <- sandwich::vcovCL(fd_manual, cluster = short$year, type = "HC1", cadjust = TRUE)
V_2way_pkg <- sandwich::vcovCL(fd_manual, cluster = short[c("firm", "year")], type = "HC1", cadjust = TRUE)

# Period effects and firm-growth-intercept tests ------------------------------
fd_period <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data = short)
period_test <- stats::anova(fd_manual, fd_period)
stopifnot(abs(coef(fd_period)["dlvalue"] - 0.495709) < 1e-6)
stopifnot(abs(coef(fd_period)["dlcapital"] - (-0.085693)) < 1e-6)
stopifnot(abs(summary(fd_period)$r.squared - 0.492530736506) < 1e-10)
stopifnot(abs(summary(fd_period)$adj.r.squared - 0.432475202364) < 1e-10)
stopifnot(abs(period_test$F[2] - 4.844946974925) < 1e-9)
stopifnot(abs(period_test$`Pr(>F)`[2] - 1.14443967246e-08) < 1e-14)

fd_firm <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(firm), data = short)
firm_test <- stats::anova(fd_manual, fd_firm)
stopifnot(abs(firm_test$F[2] - 0.194074150527) < 1e-9)
stopifnot(abs(firm_test$`Pr(>F)`[2] - 0.99458006745) < 1e-10)

# Residual diagnostics --------------------------------------------------------
DW <- unname(lmtest::dwtest(fd_manual)$statistic)
DW_period <- unname(lmtest::dwtest(fd_period)$statistic)
stopifnot(abs(DW - 2.01472905295) < 1e-8)
stopifnot(abs(DW_period - 2.04839694484) < 1e-8)

jb_fun <- function(e) {
  n <- length(e); z <- e - mean(e)
  s <- mean(z^3) / mean(z^2)^(3/2)
  k <- mean(z^4) / mean(z^2)^2
  stat <- n / 6 * (s^2 + (k - 3)^2 / 4)
  c(statistic = stat, p.value = stats::pchisq(stat, df = 2, lower.tail = FALSE))
}
JB <- jb_fun(residuals(fd_manual))
stopifnot(abs(JB["statistic"] - 0.498459918699) < 1e-8)

short$resid <- residuals(fd_manual)
short$fitted <- fitted(fd_manual)
adj_pairs <- short |>
  dplyr::group_by(firm) |>
  dplyr::arrange(year, .by_group = TRUE) |>
  dplyr::mutate(lag_resid = dplyr::lag(resid)) |>
  dplyr::ungroup() |>
  dplyr::filter(!is.na(lag_resid))
adj_rho <- stats::cor(adj_pairs$resid, adj_pairs$lag_resid)
stopifnot(abs(adj_rho - (-0.039442882889)) < 1e-10)

period_resid_means <- short |>
  dplyr::group_by(year) |>
  dplyr::summarise(mean_residual = mean(resid), .groups = "drop")

# Arithmetic first-difference comparison -------------------------------------
fd_arithmetic <- stats::lm(dinvest_level ~ dvalue_level + dcapital_level, data = dat)
expected_arith <- c(`(Intercept)` = -1.818890, dvalue_level = 0.089762, dcapital_level = 0.291767)
stopifnot(max(abs(coef(fd_arithmetic) - expected_arith)) < 1e-6)
stopifnot(abs(summary(fd_arithmetic)$r.squared - 0.408877350771) < 1e-10)
stopifnot(abs(unname(lmtest::dwtest(fd_arithmetic)$statistic) - 1.61225567571) < 1e-8)

# Within estimator comparison for Chapter 9 bridge ---------------------------
fe_within <- plm::plm(linvest ~ lvalue + lcapital, data = pdata_log, model = "within", effect = "individual")

# Export tables/results -------------------------------------------------------
utils::write.csv(as.data.frame(coef(summary(fd_manual))), "tables/chapter08/fd_baseline_coefficients.csv")
utils::write.csv(as.data.frame(coef(summary(fd_period))), "tables/chapter08/fd_period_coefficients.csv")
utils::write.csv(as.data.frame(cov_se), "tables/chapter08/fd_covariance_sensitivity.csv")
utils::write.csv(as.data.frame(period_test), "tables/chapter08/period_effect_joint_test.csv")
utils::write.csv(as.data.frame(firm_test), "tables/chapter08/firm_growth_joint_test.csv")
utils::write.csv(period_resid_means, "results/chapter08/period_residual_means.csv", row.names = FALSE)
utils::write.csv(short, "results/chapter08/fd_fitted_residuals.csv", row.names = FALSE)

# Figures ---------------------------------------------------------------------
# Derivation schematic.
deriv <- data.frame(x = c(1, 1, 3, 3, 5), y = c(3, 1, 3, 1, 2),
                    label = c("Level equation at t", "Level equation at t-1", "Subtract", "Time-invariant terms cancel", "First-difference equation"))
p_deriv <- ggplot2::ggplot(deriv, ggplot2::aes(x, y, label = label)) +
  ggplot2::geom_label(size = 3.2) +
  ggplot2::annotate("segment", x = 1.45, xend = 2.5, y = 3, yend = 2.4, arrow = grid::arrow(length = grid::unit(0.1, "in"))) +
  ggplot2::annotate("segment", x = 1.45, xend = 2.5, y = 1, yend = 1.6, arrow = grid::arrow(length = grid::unit(0.1, "in"))) +
  ggplot2::annotate("segment", x = 3.45, xend = 4.45, y = 2, yend = 2, arrow = grid::arrow(length = grid::unit(0.1, "in"))) +
  ggplot2::coord_cartesian(xlim = c(0.4, 5.8), ylim = c(0.4, 3.6)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter08/first_difference_derivation.pdf", p_deriv, width = 7, height = 3.7)

# Theoretical covariance matrix scaled by sigma^2.
M <- diag(2, 8); M[row(M) == col(M) + 1] <- -1; M[col(M) == row(M) + 1] <- -1
Mdf <- as.data.frame(as.table(M)); names(Mdf) <- c("row", "col", "value")
p_covmat <- ggplot2::ggplot(Mdf, ggplot2::aes(col, row, fill = value)) + ggplot2::geom_tile() +
  ggplot2::geom_text(ggplot2::aes(label = value), size = 3) +
  ggplot2::scale_fill_gradient2(midpoint = 0) + ggplot2::labs(x = "Differenced period", y = "Differenced period", fill = "Cov./sigma^2") +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter08/fd_error_covariance.pdf", p_covmat, width = 5.6, height = 4.8)

# Coefficient comparison: pooled levels, within FE, baseline FD, FD + period effects.
level_pool <- stats::lm(linvest ~ lvalue + lcapital, data = dat)
coef_compare <- data.frame(
  estimator = rep(c("Pooled logged levels", "Within FE", "FD baseline", "FD + period effects"), each = 2),
  regressor = rep(c("value", "capital"), 4),
  estimate = c(coef(level_pool)["lvalue"], coef(level_pool)["lcapital"], coef(fe_within),
               coef(fd_manual)["dlvalue"], coef(fd_manual)["dlcapital"],
               coef(fd_period)["dlvalue"], coef(fd_period)["dlcapital"])
)
p_comp <- ggplot2::ggplot(coef_compare, ggplot2::aes(estimator, estimate, shape = regressor, group = regressor)) +
  ggplot2::geom_point(size = 2.6) + ggplot2::geom_line() +
  ggplot2::labs(x = NULL, y = "Estimated slope", shape = NULL) + ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))
ggplot2::ggsave("figures/chapter08/coefficient_comparison.pdf", p_comp, width = 7, height = 4.2)

# Observation loss.
obs_loss <- data.frame(firm = factor(1:10), levels = 1:10, level = 20, difference = 19)
obs_long <- tidyr::pivot_longer(obs_loss, c(level, difference), names_to = "sample", values_to = "observations")
p_loss <- ggplot2::ggplot(obs_long, ggplot2::aes(firm, observations, shape = sample, group = sample)) +
  ggplot2::geom_point(size = 2.2) + ggplot2::geom_line() +
  ggplot2::labs(x = "Firm", y = "Observations", shape = NULL) + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter08/observation_loss.pdf", p_loss, width = 6.5, height = 3.5)

# Actual/fitted cross-sectional means by period.
fit_profile <- short |>
  dplyr::group_by(year) |>
  dplyr::summarise(actual = mean(dlinvest), fitted = mean(fitted), .groups = "drop") |>
  tidyr::pivot_longer(c(actual, fitted), names_to = "series", values_to = "value")
p_fit <- ggplot2::ggplot(fit_profile, ggplot2::aes(year, value, linetype = series)) +
  ggplot2::geom_hline(yintercept = 0, linewidth = 0.25) + ggplot2::geom_line(linewidth = 0.7) + ggplot2::geom_point(size = 1) +
  ggplot2::labs(x = "Teaching-period label", y = "Mean investment log change", linetype = NULL) + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter08/fd_actual_fitted.pdf", p_fit, width = 7, height = 4.2)

# Covariance sensitivity plot.
se_df <- as.data.frame(cov_se)
se_df$covariance <- rownames(se_df)
rownames(se_df) <- NULL
se_long <- se_df |>
  tidyr::pivot_longer(-covariance, names_to = "term", values_to = "std.error") |>
  dplyr::filter(term != "(Intercept)")
p_se <- ggplot2::ggplot(se_long, ggplot2::aes(covariance, std.error, shape = term, group = term)) +
  ggplot2::geom_point(size = 2.3) + ggplot2::geom_line() +
  ggplot2::labs(x = NULL, y = "Standard error", shape = NULL) + ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 22, hjust = 1))
ggplot2::ggsave("figures/chapter08/fd_covariance_sensitivity.pdf", p_se, width = 7, height = 4.2)

# Period residual means.
p_pr <- ggplot2::ggplot(period_resid_means, ggplot2::aes(year, mean_residual)) +
  ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) + ggplot2::geom_col() +
  ggplot2::labs(x = "Teaching-period label", y = "Mean baseline FD residual") + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter08/period_residual_means.pdf", p_pr, width = 7, height = 4)

writeLines(capture.output(sessionInfo()), "results/chapter08/sessionInfo.txt")
message("Chapter 8 benchmark reproduced; manual FD and plm(model='fd') coefficients agree.")
