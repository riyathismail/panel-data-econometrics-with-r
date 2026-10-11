# Attach plm for model calls evaluated by its diagnostic helpers.
library(plm)
# Chapter 20 - Heterogeneous Panels, Mean Groups, and Common Factors
# Run from the RStudio project root: source("R/chapter20.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "plm", "numDeriv")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))
for (d in c("tables/chapter20", "results/chapter20", "figures/chapter20"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest = log(invest), lvalue = log(value), lcapital = log(capital),
    dlinvest = linvest - dplyr::lag(linvest),
    dlvalue = lvalue - dplyr::lag(lvalue),
    dlcapital = lcapital - dplyr::lag(lcapital),
    L_linvest = dplyr::lag(linvest),
    L_lvalue = dplyr::lag(lvalue),
    L_lcapital = dplyr::lag(lcapital)
  ) |>
  dplyr::ungroup()
stopifnot(nrow(dat) == 200L, dplyr::n_distinct(dat$firm) == 10L,
          dplyr::n_distinct(dat$year) == 20L, !anyDuplicated(dat[c("firm", "year")]))
short <- dat |>
  dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
stopifnot(nrow(short) == 190L)
pdata <- plm::pdata.frame(short, index = c("firm", "year"), drop.index = FALSE)

# Explicit CR1 covariance -----------------------------------------------------
vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  g <- as.factor(cluster); G <- nlevels(g); n <- nrow(X); k <- ncol(X)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X))
  (G / (G - 1)) * ((n - 1) / (n - k)) * bread %*% crossprod(S) %*% bread
}

# Common slopes and classical interaction test -------------------------------
restricted <- stats::lm(
  dlinvest ~ dlvalue + dlcapital + factor(firm) + factor(year), data = short
)
unrestricted <- stats::lm(
  dlinvest ~ factor(year) + dlvalue * factor(firm) + dlcapital * factor(firm), data = short
)
A <- stats::anova(restricted, unrestricted)
F_inter <- A$F[2]; p_inter <- A$`Pr(>F)`[2]
V_period <- vcov_cr1(restricted, short$year)
se_period <- sqrt(diag(V_period))
stopifnot(abs(coef(restricted)["dlvalue"] - 0.484746682) < 1e-8,
          abs(coef(restricted)["dlcapital"] - (-0.105150291)) < 1e-8,
          abs(summary(restricted)$r.squared - 0.500977273) < 1e-8,
          abs(deviance(restricted) - 6.543589197) < 1e-8,
          abs(se_period["dlvalue"] - 0.078589838) < 1e-8,
          abs(se_period["dlcapital"] - 0.043752066) < 1e-8,
          abs(F_inter - 1.369426153) < 1e-8,
          abs(p_inter - 0.155726828) < 1e-8)

# Manual MG/DMG/CCEMG --------------------------------------------------------
fit_firms <- function(data, formula, slope_names) {
  rows <- lapply(split(data, data$firm), function(z) {
    m <- stats::lm(formula, data = z)
    data.frame(firm = z$firm[1], term = slope_names,
               estimate = unname(coef(m)[slope_names]),
               std.error = unname(sqrt(diag(vcov(m)))[slope_names]))
  })
  dplyr::bind_rows(rows)
}
mg_ind <- fit_firms(short, dlinvest ~ dlvalue + dlcapital, c("dlvalue", "dlcapital"))

td <- short |>
  dplyr::group_by(year) |>
  dplyr::mutate(
    dlinvest_td = dlinvest - mean(dlinvest),
    dlvalue_td = dlvalue - mean(dlvalue),
    dlcapital_td = dlcapital - mean(dlcapital)
  ) |>
  dplyr::ungroup()
dmg_ind <- fit_firms(td, dlinvest_td ~ dlvalue_td + dlcapital_td,
                     c("dlvalue_td", "dlcapital_td")) |>
  dplyr::mutate(term = dplyr::recode(term,
    dlvalue_td = "dlvalue", dlcapital_td = "dlcapital"))

cce <- short |>
  dplyr::group_by(year) |>
  dplyr::mutate(
    dlinvest_bar = mean(dlinvest), dlvalue_bar = mean(dlvalue), dlcapital_bar = mean(dlcapital),
    dlinvest_loo = (sum(dlinvest) - dlinvest) / (dplyr::n() - 1),
    dlvalue_loo = (sum(dlvalue) - dlvalue) / (dplyr::n() - 1),
    dlcapital_loo = (sum(dlcapital) - dlcapital) / (dplyr::n() - 1)
  ) |>
  dplyr::ungroup()
ccemg_ind <- fit_firms(cce,
  dlinvest ~ dlvalue + dlcapital + dlinvest_bar + dlvalue_bar + dlcapital_bar,
  c("dlvalue", "dlcapital"))
ccemg_loo_ind <- fit_firms(cce,
  dlinvest ~ dlvalue + dlcapital + dlinvest_loo + dlvalue_loo + dlcapital_loo,
  c("dlvalue", "dlcapital"))

mg_aggregate <- function(ind, estimator) {
  ind |>
    dplyr::group_by(term) |>
    dplyr::summarise(
      std.error = stats::sd(estimate) / sqrt(dplyr::n()),
      minimum = min(estimate), maximum = max(estimate),
      estimate = mean(estimate), .groups = "drop"
    ) |>
    dplyr::mutate(
      estimator = estimator, df = 9,
      statistic = estimate / std.error,
      p.value = 2 * stats::pt(abs(statistic), df = df, lower.tail = FALSE)
    )
}
agg <- dplyr::bind_rows(
  mg_aggregate(mg_ind, "Raw MG"),
  mg_aggregate(dmg_ind, "Time-demeaned MG"),
  mg_aggregate(ccemg_ind, "CCEMG"),
  mg_aggregate(ccemg_loo_ind, "Leave-one-out CCEMG")
)
# Hard benchmarks.
bench <- list(
  raw_v = c(0.43311817, 0.12441030), raw_k = c(-0.67164951, 0.34236888),
  dmg_v = c(0.52646294, 0.13515296), dmg_k = c(-0.14882113, 0.07242914),
  cce_v = c(0.37706937, 0.14461844), cce_k = c(-0.59494311, 0.34403724),
  loo_v = c(0.35916313, 0.12964327), loo_k = c(-0.68143186, 0.37423404)
)
getrow <- function(est, term) agg[agg$estimator == est & agg$term == term, ]
stopifnot(max(abs(unlist(getrow("Raw MG", "dlvalue")[c("estimate","std.error")]) - bench$raw_v)) < 1e-7,
          max(abs(unlist(getrow("Raw MG", "dlcapital")[c("estimate","std.error")]) - bench$raw_k)) < 1e-7,
          max(abs(unlist(getrow("Time-demeaned MG", "dlvalue")[c("estimate","std.error")]) - bench$dmg_v)) < 1e-7,
          max(abs(unlist(getrow("Time-demeaned MG", "dlcapital")[c("estimate","std.error")]) - bench$dmg_k)) < 1e-7,
          max(abs(unlist(getrow("CCEMG", "dlvalue")[c("estimate","std.error")]) - bench$cce_v)) < 1e-7,
          max(abs(unlist(getrow("CCEMG", "dlcapital")[c("estimate","std.error")]) - bench$cce_k)) < 1e-7)

# Package-native cross-checks. IMPORTANT: plm::pmg() is NOT PSS pooled mean group.
mg_plm <- plm::pmg(dlinvest ~ dlvalue + dlcapital, data = pdata, model = "mg")
dmg_plm <- plm::pmg(dlinvest ~ dlvalue + dlcapital, data = pdata, model = "dmg")
ccemg_plm <- plm::pmg(dlinvest ~ dlvalue + dlcapital, data = pdata, model = "cmg")
ccep_plm <- plm::pcce(dlinvest ~ dlvalue + dlcapital, data = pdata, model = "p")
ccemg_pcce <- plm::pcce(dlinvest ~ dlvalue + dlcapital, data = pdata, model = "mg")
stopifnot(max(abs(unname(coef(mg_plm)[c("dlvalue","dlcapital")]) - c(0.43311817,-0.67164951))) < 1e-6,
          max(abs(unname(coef(dmg_plm)[c("dlvalue","dlcapital")]) - c(0.52646294,-0.14882113))) < 1e-6,
          max(abs(unname(coef(ccemg_plm)[c("dlvalue","dlcapital")]) - c(0.37706937,-0.59494311))) < 1e-6)

# Dynamic MG and DFE ---------------------------------------------------------
dyn <- dat |>
  dplyr::filter(stats::complete.cases(
    dlinvest, L_linvest, L_lvalue, L_lcapital, dlvalue, dlcapital
  ))
fit_dynamic_firm <- function(z) {
  m <- stats::lm(dlinvest ~ L_linvest + L_lvalue + L_lcapital + dlvalue + dlcapital, data = z)
  b <- coef(m); phi <- b["L_linvest"]
  data.frame(firm = z$firm[1], phi = phi,
    weak_adjustment = abs(phi) < 0.05,
    theta_value = -b["L_lvalue"] / phi,
    theta_capital = -b["L_lcapital"] / phi,
    delta_value = b["dlvalue"], delta_capital = b["dlcapital"],
    p_phi = coef(summary(m))["L_linvest","Pr(>|t|)"], ssr = deviance(m))
}
mg_dynamic <- dplyr::bind_rows(lapply(split(dyn, dyn$firm), fit_dynamic_firm))
stopifnot(abs(mean(mg_dynamic$phi) - (-0.708937893)) < 1e-8,
          abs(stats::median(mg_dynamic$phi) - (-0.506352521)) < 1e-8,
          sum(mg_dynamic$p_phi < 0.05) == 5L,
          abs(mean(mg_dynamic$theta_value) - 1.962358971) < 1e-8,
          abs(mean(mg_dynamic$theta_capital) - 0.038200865) < 1e-8)

dfe <- stats::lm(dlinvest ~ L_linvest + L_lvalue + L_lcapital + dlvalue + dlcapital + factor(firm), data = dyn)
bd <- coef(dfe); phi_dfe <- bd["L_linvest"]
theta_v_dfe <- -bd["L_lvalue"] / phi_dfe; theta_k_dfe <- -bd["L_lcapital"] / phi_dfe
stopifnot(abs(phi_dfe - (-0.284928883)) < 1e-8,
          abs(theta_v_dfe - 0.871070689) < 1e-8,
          abs(theta_k_dfe - 0.194448438) < 1e-8,
          abs(bd["dlvalue"] - 0.631314332) < 1e-8,
          abs(bd["dlcapital"] - 0.001873508) < 1e-8)

# Transparent PSS-PMG restriction ------------------------------------------
pmg_profile <- function(theta, dyn, return_coefs = FALSE) {
  fits <- lapply(split(dyn, dyn$firm), function(z) {
    ect <- z$L_linvest - theta[1] * z$L_lvalue - theta[2] * z$L_lcapital
    X <- cbind(1, ect, z$dlvalue, z$dlcapital)
    fit <- stats::lm.fit(X, z$dlinvest)
    list(coef = fit$coefficients, resid = fit$residuals)
  })
  ssr <- sum(vapply(fits, function(x) sum(x$resid^2), numeric(1)))
  if (return_coefs) return(list(ssr = ssr, coefs = do.call(rbind, lapply(fits, `[[`, "coef"))))
  ssr
}
pmg_profile_ssr <- function(theta, dyn) pmg_profile(theta, dyn, FALSE)
pmg_opt <- stats::optim(c(0.65, 0.20), pmg_profile_ssr, dyn = dyn, method = "BFGS",
                        control = list(reltol = 1e-12, maxit = 10000))
pmg_fit <- pmg_profile(pmg_opt$par, dyn, TRUE)
stopifnot(max(abs(pmg_opt$par - c(0.65290813, 0.19611245))) < 1e-6,
          abs(pmg_fit$ssr - 6.522618428) < 1e-7,
          sum(pmg_fit$coefs[,2] < 0) == 9L,
          abs(mean(pmg_fit$coefs[,2]) - (-0.520057794)) < 2e-7)
# Teaching NLS covariance from numerical Jacobian of the full residual vector.
pmg_residuals_full <- function(par, dyn) {
  theta <- par[1:2]; P <- matrix(par[-(1:2)], nrow = 10, byrow = TRUE)
  pieces <- Map(function(z, i) {
    ect <- z$L_linvest - theta[1] * z$L_lvalue - theta[2] * z$L_lcapital
    pred <- P[i,1] + P[i,2] * ect + P[i,3] * z$dlvalue + P[i,4] * z$dlcapital
    z$dlinvest - pred
  }, split(dyn, dyn$firm), seq_len(10))
  unlist(pieces, use.names = FALSE)
}
start <- c(pmg_opt$par, as.vector(t(pmg_fit$coefs)))
J <- numDeriv::jacobian(pmg_residuals_full, start, dyn = dyn)
e <- pmg_residuals_full(start, dyn); sigma2 <- sum(e^2) / (length(e) - length(start))
V_nls <- sigma2 * solve(crossprod(J)); pmg_se <- sqrt(diag(V_nls))[1:2]
stopifnot(max(abs(pmg_se - c(0.12274353, 0.07672489))) < 2e-6)

# Descriptive restriction comparisons.
ssr_mg <- sum(mg_dynamic$ssr)
F_pmg <- ((pmg_fit$ssr - ssr_mg) / 18) / (ssr_mg / 130)
F_dfe <- ((deviance(dfe) - ssr_mg) / 45) / (ssr_mg / 130)
stopifnot(abs(F_pmg - 1.332094766) < 1e-8, abs(F_dfe - 1.749536331) < 1e-8)

# Exports --------------------------------------------------------------------
utils::write.csv(agg, "tables/chapter20/static_mg_cce_summary.csv", row.names = FALSE)
utils::write.csv(dmg_ind, "tables/chapter20/firm_specific_time_demeaned_slopes_R.csv", row.names = FALSE)
utils::write.csv(mg_dynamic, "tables/chapter20/firm_specific_ardl_mg_R.csv", row.names = FALSE)
utils::write.csv(data.frame(firm = 1:10, phi_pmg = pmg_fit$coefs[,2]),
                 "tables/chapter20/pmg_adjustment_coefficients_R.csv", row.names = FALSE)
writeLines(capture.output(summary(mg_plm), summary(dmg_plm), summary(ccemg_plm), summary(ccep_plm)),
           "results/chapter20/plm_package_crosschecks.txt")
if (requireNamespace("PooledMeanGroup", quietly = TRUE)) {
  writeLines(c("PooledMeanGroup package detected.",
    "The book release benchmark is the transparent profile-NLS PMG reconstruction.",
    "Use the package as a secondary PSS-PMG software cross-check after validating its data assembly and sign conventions."),
    "results/chapter20/PooledMeanGroup_package_note.txt")
}
writeLines(capture.output(sessionInfo()), "results/chapter20/sessionInfo.txt")

# Figures --------------------------------------------------------------------
firm_wide <- tidyr::pivot_wider(dmg_ind, names_from = term, values_from = c(estimate, std.error))
p1 <- ggplot2::ggplot(firm_wide, ggplot2::aes(y = factor(firm))) +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = estimate_dlvalue - 1.96 * std.error_dlvalue,
                                     xmax = estimate_dlvalue + 1.96 * std.error_dlvalue), width = 0.12) +
  ggplot2::geom_point(ggplot2::aes(x = estimate_dlvalue, shape = "Market-value growth")) +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = estimate_dlcapital - 1.96 * std.error_dlcapital,
                                     xmax = estimate_dlcapital + 1.96 * std.error_dlcapital), width = 0.12) +
  ggplot2::geom_point(ggplot2::aes(x = estimate_dlcapital, shape = "Capital-stock growth")) +
  ggplot2::geom_vline(xintercept = 0) +
  ggplot2::labs(x = "Firm-specific time-demeaned slope", y = "Firm", shape = NULL) +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter20/firm_specific_slopes.pdf", p1, width = 7, height = 4.4)

cmp <- agg |>
  dplyr::filter(estimator %in% c("Raw MG","Time-demeaned MG","CCEMG","Leave-one-out CCEMG"))
fe_rows <- data.frame(term = c("dlvalue","dlcapital"), estimate = coef(restricted)[c("dlvalue","dlcapital")],
                      std.error = se_period[c("dlvalue","dlcapital")], estimator = "Two-way FE")
cmp <- dplyr::bind_rows(fe_rows, cmp)
p2 <- ggplot2::ggplot(cmp, ggplot2::aes(estimator, estimate, shape = term, group = term)) +
  ggplot2::geom_hline(yintercept = 0) + ggplot2::geom_point(size = 2.3) +
  ggplot2::geom_errorbar(ggplot2::aes(ymin = estimate - 2.262 * std.error, ymax = estimate + 2.262 * std.error), width = 0.12) +
  ggplot2::labs(x = NULL, y = "Slope estimate", shape = NULL) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1))
ggplot2::ggsave("figures/chapter20/estimator_comparison.pdf", p2, width = 7, height = 4.4)

lr <- data.frame(model = c("MG mean","MG median","PSS-PMG","DFE"),
  theta_value = c(mean(mg_dynamic$theta_value), median(mg_dynamic$theta_value), pmg_opt$par[1], theta_v_dfe),
  theta_capital = c(mean(mg_dynamic$theta_capital), median(mg_dynamic$theta_capital), pmg_opt$par[2], theta_k_dfe)) |>
  tidyr::pivot_longer(c(theta_value, theta_capital), names_to = "term", values_to = "estimate")
p3 <- ggplot2::ggplot(lr, ggplot2::aes(model, estimate, fill = term)) + ggplot2::geom_col(position = "dodge") +
  ggplot2::geom_hline(yintercept = 0) + ggplot2::labs(x = NULL, y = "Long-run coefficient / ratio", fill = NULL) +
  ggplot2::theme_minimal(base_size = 10) + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 15, hjust = 1))
ggplot2::ggsave("figures/chapter20/ardl_restriction_comparison.pdf", p3, width = 7, height = 4.2)

phi_df <- data.frame(firm = factor(1:10), phi = pmg_fit$coefs[,2])
p4 <- ggplot2::ggplot(phi_df, ggplot2::aes(firm, phi)) + ggplot2::geom_col() + ggplot2::geom_hline(yintercept = 0) +
  ggplot2::labs(x = "Firm", y = "PSS-PMG adjustment coefficient") + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter20/pmg_adjustment_coefficients.pdf", p4, width = 7, height = 3.9)
message("Chapter 20 benchmark reproduced. Note: plm::pmg() = MG/DMG/CCEMG, not PSS-PMG.")
