# Chapter 17 — Panel Cointegration and Error-Correction Models
# Run from the RStudio Project root: source("R/chapter17.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "pco", "urca", "aTSA")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter17", "results/chapter17", "figures/chapter17"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---------- Data and transformations ----------
dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::mutate(row_id = dplyr::row_number()) |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest = log(invest), lvalue = log(value), lcapital = log(capital),
    dlinvest = linvest - dplyr::lag(linvest),
    dlvalue = lvalue - dplyr::lag(lvalue),
    dlcapital = lcapital - dplyr::lag(lcapital)
  ) |>
  dplyr::ungroup()
stopifnot(nrow(dat) == 200L, dplyr::n_distinct(dat$firm) == 10L,
          dplyr::n_distinct(dat$year) == 20L,
          !anyDuplicated(dat[c("firm", "year")]))

# ---------- Cross-sectional dependence screen in first log differences ----------
cd_manual <- function(data, var) {
  x <- tidyr::pivot_wider(data[!is.na(data[[var]]), c("firm", "year", var)],
                          names_from = firm, values_from = dplyr::all_of(var))
  M <- as.matrix(x[-1])
  R <- stats::cor(M)
  N <- ncol(M); Tn <- nrow(M)
  vals <- R[upper.tri(R)]
  cd <- sqrt(2 * Tn / (N * (N - 1))) * sum(vals)
  data.frame(variable = var, average_pairwise_correlation = mean(vals),
             CD = cd, p_value = 2 * stats::pnorm(abs(cd), lower.tail = FALSE))
}
cd_table <- dplyr::bind_rows(lapply(c("dlinvest", "dlvalue", "dlcapital"), function(v) cd_manual(dat, v)))
utils::write.csv(cd_table, "tables/chapter17/cross_section_dependence.csv", row.names = FALSE)
stopifnot(max(abs(cd_table$average_pairwise_correlation - c(0.335002806, 0.501975729, 0.234883187))) < 1e-8)
stopifnot(max(abs(cd_table$CD - c(9.795610355, 14.677962579, 6.868074368))) < 1e-8)

# ---------- Firm-specific Engle-Granger comparison ----------
source('R/unit_root_helpers.R')
# Reproduce the printed convention in R: intercept in the levels equation,
# AIC selection over 0/1 residual ADF lags, no residual-stage intercept,
# MacKinnon (1994) asymptotic cointegration probabilities with N=3.
case_eg <- do.call(rbind,lapply(split(dat,dat$firm),function(g) {
  a<-engle_granger_case(g$linvest,as.matrix(g[c('lvalue','lcapital')]))
  data.frame(firm=g$firm[1],statistic=a$statistic,p_value=a$p_value,
             reject_5pct=a$p_value<.05,lag=a$lag)
}))
reference<-read.csv('validation/chapter17/engle_granger_benchmark.csv')
stopifnot(max(abs(case_eg$statistic-reference$statistic))<5e-5,
          max(abs(case_eg$p_value-reference$p_value))<5e-5)
write.csv(case_eg,'tables/chapter17/engle_granger_recomputed.csv',row.names=FALSE)
fisher_eg <- -2*sum(log(case_eg$p_value))
stopifnot(abs(fisher_eg-100.1256)<5e-5)
# aTSA::coint.test() is the live-R multivariate EG implementation used for reproducibility.
# Its exact lag/type output is exported, not forced to match another package's response-surface convention.
eg_list <- lapply(split(dat, dat$firm), function(g) {
  aTSA::coint.test(g$linvest, as.matrix(g[c("lvalue", "lcapital")]), d = 0, nlag = 1, output = FALSE)
})
writeLines(capture.output(eg_list), "results/chapter17/engle_granger_aTSA.txt")

# ---------- Pedroni 1999 sensitivity ----------
make_pedroni_cube <- function(data, vars) {
  firms <- sort(unique(data$firm)); years <- sort(unique(data$year))
  A <- array(NA_real_, dim = c(length(years), length(firms), length(vars)),
             dimnames = list(year = years, firm = firms, variable = vars))
  for (j in seq_along(vars)) {
    z <- tidyr::pivot_wider(data[c("firm", "year", vars[j])], names_from = firm,
                            values_from = dplyr::all_of(vars[j])) |>
      dplyr::arrange(year)
    A[, , j] <- as.matrix(z[-1])
  }
  A
}
ped_cube <- make_pedroni_cube(dat, c("linvest", "lvalue", "lcapital"))
pedroni_r <- pco::pedroni99m(ped_cube, kk = 1, type.stat = 2, ka = 2)
utils::write.csv(as.data.frame(pedroni_r$STATISTIC), "tables/chapter17/pedroni99m_statistics.csv")

# ---------- Individual Johansen diagnostics ----------
johansen_by_firm <- lapply(split(dat, dat$firm), function(g) {
  z <- as.matrix(g[c("linvest", "lvalue", "lcapital")])
  urca::ca.jo(z, type = "trace", ecdet = "const", K = 2, spec = "longrun")
})
writeLines(capture.output(lapply(johansen_by_firm, summary)), "results/chapter17/johansen_by_firm.txt")

# ---------- Static FE comparison ----------
oneway <- stats::lm(linvest ~ lvalue + lcapital + factor(firm), data = dat)
twoway <- stats::lm(linvest ~ lvalue + lcapital + factor(firm) + factor(year), data = dat)
stopifnot(max(abs(coef(oneway)[c("lvalue", "lcapital")] - c(0.591847307, 0.255918016))) < 1e-8)
stopifnot(max(abs(coef(twoway)[c("lvalue", "lcapital")] - c(0.328554135, 0.076795861))) < 1e-8)

# ---------- CR1 covariance helper ----------
vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X))
  correction <- (G / (G - 1)) * ((n - 1) / (n - k))
  correction * bread %*% crossprod(S) %*% bread
}
cluster_row <- function(model, V, term, df_ref) {
  b <- coef(model)[term]; se <- sqrt(V[term, term]); tt <- b / se
  q <- stats::qt(0.975, df_ref)
  data.frame(term = term, estimate = unname(b), std.error = se, statistic = unname(tt),
             p.value = 2 * stats::pt(abs(tt), df_ref, lower.tail = FALSE),
             conf.low = unname(b - q * se), conf.high = unname(b + q * se), df = df_ref)
}

# ---------- Transparent two-way DOLS q=1 ----------
dols <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    L_dlvalue = dplyr::lag(dlvalue), F_dlvalue = dplyr::lead(dlvalue),
    L_dlcapital = dplyr::lag(dlcapital), F_dlcapital = dplyr::lead(dlcapital)
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(stats::complete.cases(linvest, lvalue, lcapital,
                                      L_dlvalue, dlvalue, F_dlvalue,
                                      L_dlcapital, dlcapital, F_dlcapital))
stopifnot(nrow(dols) == 170L, dplyr::n_distinct(dols$year) == 17L,
          min(dols$year) == 2008, max(dols$year) == 2024)
dols_fit <- stats::lm(
  linvest ~ lvalue + lcapital + L_dlvalue + dlvalue + F_dlvalue +
    L_dlcapital + dlcapital + F_dlcapital + factor(firm) + factor(year), data = dols)
stopifnot(max(abs(coef(dols_fit)[c("lvalue", "lcapital")] - c(0.335917039, 0.325829501))) < 1e-8)
V_dols <- vcov_cr1(dols_fit, dols$year)
dols_inf <- dplyr::bind_rows(
  cluster_row(dols_fit, V_dols, "lvalue", 16),
  cluster_row(dols_fit, V_dols, "lcapital", 16)
)
expected_dols_se <- c(0.093269722, 0.039887842)
stopifnot(max(abs(dols_inf$std.error - expected_dols_se)) < 1e-8)
utils::write.csv(dols_inf, "tables/chapter17/dols_period_cluster.csv", row.names = FALSE)

# ---------- Conditional ECM ----------
dat$ect_dols <- NA_real_
X_dols <- model.matrix(dols_fit)
short_terms <- c("L_dlvalue", "dlvalue", "F_dlvalue",
                 "L_dlcapital", "dlcapital", "F_dlcapital")
equilibrium_error <- residuals(dols_fit) + as.vector(
  X_dols[, short_terms, drop = FALSE] %*% coef(dols_fit)[short_terms])
dat$ect_dols[match(dols$row_id, dat$row_id)] <- equilibrium_error
dat <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(ect_lag1 = dplyr::lag(ect_dols)) |>
  dplyr::ungroup()
ecm_dat <- dat |>
  dplyr::filter(stats::complete.cases(dlinvest, ect_lag1, dlvalue, dlcapital))
stopifnot(nrow(ecm_dat) == 170L, dplyr::n_distinct(ecm_dat$year) == 17L,
          min(ecm_dat$year) == 2009, max(ecm_dat$year) == 2025)
ecm_fit <- stats::lm(dlinvest ~ ect_lag1 + dlvalue + dlcapital + factor(year), data = ecm_dat)
expected_ecm <- c(ect_lag1 = -0.403745405145, dlvalue = 0.461710058572, dlcapital = 0.146026470576)
stopifnot(max(abs(coef(ecm_fit)[names(expected_ecm)] - expected_ecm)) < 1e-8)
V_ecm <- vcov_cr1(ecm_fit, ecm_dat$year)
ecm_inf <- dplyr::bind_rows(lapply(names(expected_ecm), function(tt) cluster_row(ecm_fit, V_ecm, tt, 16)))
stopifnot(max(abs(ecm_inf$std.error - c(0.070816727171, 0.084685779372, 0.129011485183))) < 1e-8)
utils::write.csv(ecm_inf, "tables/chapter17/ecm_period_cluster.csv", row.names = FALSE)

R <- matrix(0, 2, length(coef(ecm_fit)), dimnames = list(NULL, names(coef(ecm_fit))))
R[1, "dlvalue"] <- 1; R[2, "dlcapital"] <- 1
Rb <- as.vector(R %*% coef(ecm_fit)); RV <- R %*% V_ecm %*% t(R)
wald <- as.numeric(t(Rb) %*% solve(RV, Rb)); Fjoint <- wald / 2
pF <- stats::pf(Fjoint, 2, 16, lower.tail = FALSE)
stopifnot(abs(Fjoint - 14.875411135523) < 1e-8, abs(pF - 0.0002237529) < 1e-9)
phi <- coef(ecm_fit)["ect_lag1"]
half_life <- log(0.5) / log(1 + phi)
stopifnot(abs(half_life - 1.340483) < 1e-6)
writeLines(sprintf("F(2,16)=%.12f; p=%.12g; half-life=%.12f", Fjoint, pF, half_life),
           "results/chapter17/ecm_joint_test.txt")

# ---------- Figures ----------
# Generated here in the final R run; review-PDF figures are independently regenerated in Python.
p1 <- ggplot2::ggplot(case_eg, ggplot2::aes(factor(firm), p_value, shape = reject_5pct)) +
  ggplot2::geom_point(size = 2.5) + ggplot2::geom_hline(yintercept = .05, linetype = 2) +
  ggplot2::labs(x = "Firm", y = "MacKinnon asymptotic probability", shape = "Reject at 5%") +
  ggplot2::theme_minimal(base_size = 14)
ggplot2::ggsave("figures/chapter17/individual_cointegration_evidence.pdf", p1, width = 7, height = 4.2, device = grDevices::cairo_pdf)

cmp <- data.frame(estimator = factor(c("One-way FE", "Two-way FE", "Two-way DOLS"),
                                     levels = c("One-way FE", "Two-way FE", "Two-way DOLS")),
                  value = c(coef(oneway)["lvalue"], coef(twoway)["lvalue"], coef(dols_fit)["lvalue"]),
                  capital = c(coef(oneway)["lcapital"], coef(twoway)["lcapital"], coef(dols_fit)["lcapital"])) |>
  tidyr::pivot_longer(c(value, capital), names_to = "regressor", values_to = "estimate")
p2 <- ggplot2::ggplot(cmp, ggplot2::aes(estimator, estimate, group = regressor, shape = regressor)) +
  ggplot2::geom_point(size = 2.5) + ggplot2::geom_line(ggplot2::aes(linetype = regressor)) +
  ggplot2::labs(x = NULL, y = "Estimated long-run slope", shape = NULL, linetype = NULL) +
  ggplot2::theme_minimal(base_size = 14)
ggplot2::ggsave("figures/chapter17/longrun_estimator_comparison.pdf", p2, width = 7, height = 4.2, device = grDevices::cairo_pdf)

path <- data.frame(h = 0:8, disequilibrium = (1 + phi)^(0:8))
p3 <- ggplot2::ggplot(path, ggplot2::aes(h, disequilibrium)) + ggplot2::geom_line(linewidth = .8) +
  ggplot2::geom_point() + ggplot2::geom_hline(yintercept = .5, linetype = 2) +
  ggplot2::labs(x = "Periods after a one-unit disequilibrium", y = "Remaining disequilibrium") +
  ggplot2::theme_minimal(base_size = 14)
ggplot2::ggsave("figures/chapter17/ecm_adjustment_path.pdf", p3, width = 7, height = 4.2, device = grDevices::cairo_pdf)

writeLines(capture.output(sessionInfo()), "results/chapter17/sessionInfo.txt")
message("Chapter 17 benchmark complete. Pedroni/Johansen/aTSA outputs exported for live-R review.")

