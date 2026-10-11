# Chapter 10 - Random Effects and Quasi-Demeaning
# Run from the RStudio Project root: source("R/chapter10.R")

required <- c("readr", "dplyr", "tidyr", "plm", "sandwich", "ggplot2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter10", "results/chapter10", "figures/chapter10"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::mutate(linvest = log(invest), lvalue = log(value), lcapital = log(capital))
stopifnot(nrow(dat) == 200L, dplyr::n_distinct(dat$firm) == 10L,
          dplyr::n_distinct(dat$year) == 20L, !anyDuplicated(dat[c("firm", "year")]),
          !anyNA(dat[c("linvest", "lvalue", "lcapital")]))

pdata <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
stopifnot(plm::is.pbalanced(pdata))
N <- 10L; Tn <- 20L; K <- 2L

# Inputs for balanced Swamy-Arora teaching reconstruction ----------------------
pool <- plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "pooling")
fe <- plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "within", effect = "individual")
between <- plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "between")

sigma_e2 <- sum(residuals(fe)^2) / (N * Tn - N - K)
sigma_B2 <- sum(residuals(between)^2) / (N - K - 1L)
sigma_alpha2_raw <- sigma_B2 - sigma_e2 / Tn
sigma_alpha2 <- max(0, sigma_alpha2_raw)
rho <- sigma_alpha2 / (sigma_alpha2 + sigma_e2)
theta_manual <- 1 - sqrt(sigma_e2 / (sigma_e2 + Tn * sigma_alpha2))
lambda <- Tn * sigma_alpha2 / (sigma_e2 + Tn * sigma_alpha2)

stopifnot(abs(sigma_e2 - 0.0872422328358) < 1e-10)
stopifnot(abs(sigma_B2 - 0.253927728225) < 1e-10)
stopifnot(abs(sigma_alpha2 - 0.249565616583) < 1e-10)
stopifnot(abs(rho - 0.740973279018) < 1e-10)
stopifnot(abs(theta_manual - 0.868933010359) < 1e-10)
stopifnot(abs(lambda - 0.982821444226) < 1e-10)

components <- data.frame(
  component = c("idiosyncratic", "firm"),
  variance = c(sigma_e2, sigma_alpha2),
  sd = sqrt(c(sigma_e2, sigma_alpha2))
)
write.csv(components, "tables/chapter10/variance_components.csv", row.names = FALSE)

# Manual quasi-demeaning -------------------------------------------------------
dat_q <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    q_y = linvest - theta_manual * mean(linvest),
    q_x1 = lvalue - theta_manual * mean(lvalue),
    q_x2 = lcapital - theta_manual * mean(lcapital),
    q_c = 1 - theta_manual
  ) |>
  dplyr::ungroup()

re_manual <- lm(q_y ~ 0 + q_c + q_x1 + q_x2, data = dat_q)
expected_re <- c(q_c = -1.288351711, q_x1 = 0.662453320, q_x2 = 0.255515458)
stopifnot(max(abs(coef(re_manual) - expected_re)) < 1e-8)
expected_se <- c(0.463555083, 0.075447762, 0.026117237)
stopifnot(max(abs(summary(re_manual)$coefficients[, "Std. Error"] - expected_se)) < 1e-8)

# Native plm RE cross-check ----------------------------------------------------
re_swar <- plm::plm(
  linvest ~ lvalue + lcapital,
  data = pdata,
  model = "random",
  effect = "individual",
  random.method = "swar"
)
comp <- plm::ercomp(re_swar)
stopifnot(isTRUE(all.equal(unname(coef(re_manual)), unname(coef(re_swar)), tolerance = 1e-7)))
stopifnot(abs(as.numeric(comp$theta) - theta_manual) < 1e-7)

# Alternative variance-component estimators ----------------------------------
methods <- c(swar = "swar", walhus = "walhus", amemiya = "amemiya", nerlove = "nerlove")
re_alternatives <- lapply(methods, function(m) {
  plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "random",
           effect = "individual", random.method = m)
})
alt_table <- do.call(rbind, lapply(names(re_alternatives), function(nm) {
  m <- re_alternatives[[nm]]; ec <- plm::ercomp(m)
  data.frame(method = nm, intercept = coef(m)[1], lvalue = coef(m)[2], lcapital = coef(m)[3],
             theta = as.numeric(ec$theta))
}))
write.csv(alt_table, "tables/chapter10/alternative_component_estimators.csv", row.names = FALSE)

# LM tests ---------------------------------------------------------------------
lm_bp <- plm::plmtest(pool, effect = "individual", type = "bp")
lm_honda <- plm::plmtest(pool, effect = "individual", type = "honda")
stopifnot(abs(unname(lm_bp$statistic) - 754.636423561) < 1e-5)
stopifnot(abs(unname(lm_honda$statistic) - 27.470646581) < 1e-5)

# Predicted random effects and manual shrinkage -------------------------------
b <- coef(re_manual)
dat$u_raw <- dat$linvest - (b[1] + b[2] * dat$lvalue + b[3] * dat$lcapital)
manual_effects <- dat |>
  dplyr::group_by(firm) |>
  dplyr::summarise(effect_manual = lambda * mean(u_raw), .groups = "drop")
expected_effects <- c(0.567154127, 0.816771266, -0.669611464, 0.199975064, 0.241566449,
                      0.093109079, 0.328168688, -0.306201672, -0.309073862, -0.961857675)
stopifnot(max(abs(manual_effects$effect_manual - expected_effects)) < 1e-8)

plm_effects <- plm::ranef(re_swar, effect = "individual")
effects_table <- data.frame(firm = as.integer(names(plm_effects)),
                            plm_random_effect = as.numeric(plm_effects)) |>
  dplyr::left_join(manual_effects, by = "firm")
stopifnot(max(abs(effects_table$plm_random_effect - effects_table$effect_manual)) < 1e-6)
write.csv(effects_table, "tables/chapter10/predicted_random_effects.csv", row.names = FALSE)

# Covariance sensitivity on quasi-demeaned lm ---------------------------------
V_conv <- vcov(re_manual)
V_hc1 <- sandwich::vcovHC(re_manual, type = "HC1")
V_firm <- sandwich::vcovCL(re_manual, cluster = dat_q$firm, type = "HC1", cadjust = TRUE)
V_period <- sandwich::vcovCL(re_manual, cluster = dat_q$year, type = "HC1", cadjust = TRUE)
V_2way <- sandwich::vcovCL(re_manual, cluster = dat_q[c("firm", "year")], type = "HC1", cadjust = TRUE)

cov_row <- function(label, V, dfref) {
  se <- sqrt(diag(V)); bb <- coef(re_manual); tt <- bb / se
  data.frame(covariance = label, term = names(bb), estimate = unname(bb), std.error = se,
             statistic = unname(tt), p.value = 2 * pt(abs(tt), df = dfref, lower.tail = FALSE),
             df.reference = dfref, row.names = NULL)
}
covtab <- dplyr::bind_rows(
  cov_row("Conventional", V_conv, 197),
  cov_row("HC1", V_hc1, 197),
  cov_row("Firm cluster", V_firm, 9),
  cov_row("Period cluster", V_period, 19),
  cov_row("Two-way cluster", V_2way, 9)
)
bench <- covtab |>
  dplyr::filter(term %in% c("q_x1", "q_x2"))
expected_cov_se <- c(
  0.075447762, 0.026117237,
  0.084813056, 0.047286150,
  0.116015746, 0.069916932,
  0.053721599, 0.059752113,
  0.095668224, 0.078884170
)
stopifnot(max(abs(bench$std.error - expected_cov_se)) < 1e-8)
write.csv(covtab, "tables/chapter10/covariance_sensitivity.csv", row.names = FALSE)

# Mixed period-fixed / individual-random specification and two-way illustration
re_period_fe <- plm::plm(
  linvest ~ lvalue + lcapital + factor(year), data = pdata,
  model = "random", effect = "individual", random.method = "swar"
)
capture.output(summary(re_period_fe), file = "results/chapter10/re_with_period_fixed_effects.txt")

re_twoway <- try(plm::plm(
  linvest ~ lvalue + lcapital, data = pdata,
  model = "random", effect = "twoways", random.method = "swar"
), silent = TRUE)
if (!inherits(re_twoway, "try-error")) {
  capture.output(summary(re_twoway), file = "results/chapter10/twoway_random_effects.txt")
} else {
  writeLines(as.character(re_twoway), "results/chapter10/twoway_random_effects_status.txt")
}

# First-log-difference boundary case ------------------------------------------
short <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(dlinvest = linvest - dplyr::lag(linvest),
                dlvalue = lvalue - dplyr::lag(lvalue),
                dlcapital = lcapital - dplyr::lag(lcapital)) |>
  dplyr::ungroup() |>
  dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
stopifnot(nrow(short) == 190L)
pdata_d <- plm::pdata.frame(short, index = c("firm", "year"), drop.index = FALSE)
fe_d <- plm::plm(dlinvest ~ dlvalue + dlcapital, data = pdata_d, model = "within")
between_d <- plm::plm(dlinvest ~ dlvalue + dlcapital, data = pdata_d, model = "between")
sigma_e2_d <- sum(residuals(fe_d)^2) / (190 - 10 - 2)
sigma_B2_d <- sum(residuals(between_d)^2) / (10 - 2 - 1)
sigma_alpha2_d_raw <- sigma_B2_d - sigma_e2_d / 19
sigma_alpha2_d <- max(0, sigma_alpha2_d_raw)
theta_d <- if (sigma_alpha2_d == 0) 0 else 1 - sqrt(sigma_e2_d / (sigma_e2_d + 19 * sigma_alpha2_d))
stopifnot(abs(sigma_e2_d - 0.056124482802) < 1e-10)
stopifnot(abs(sigma_alpha2_d_raw - (-0.002586688116)) < 1e-10)
stopifnot(sigma_alpha2_d == 0, theta_d == 0)
pool_d <- plm::plm(dlinvest ~ dlvalue + dlcapital, data = pdata_d, model = "pooling")
lm_bp_d <- plm::plmtest(pool_d, effect = "individual", type = "bp")
lm_honda_d <- plm::plmtest(pool_d, effect = "individual", type = "honda")
stopifnot(abs(unname(lm_bp_d$statistic) - 3.562023176) < 1e-5)
stopifnot(abs(unname(lm_honda_d$statistic) - (-1.887332291)) < 1e-5)

# Tables and figures -----------------------------------------------------------
# Conceptual error-components architecture.
arch <- data.frame(
  x = c(1, 2, 2, 3), y = c(2, 3, 1, 2),
  label = c("Composite error  u_it", "Persistent firm effect  alpha_i",
            "Idiosyncratic shock  epsilon_it", "Within-firm covariance  sigma_alpha^2")
)
p0 <- ggplot2::ggplot(arch, ggplot2::aes(x, y, label = label)) +
  ggplot2::geom_label(size = 3.2) +
  ggplot2::annotate("segment", x = 1.15, xend = 1.82, y = 2.08, yend = 2.85,
                    arrow = grid::arrow(length = grid::unit(0.12, "in"))) +
  ggplot2::annotate("segment", x = 1.15, xend = 1.82, y = 1.92, yend = 1.15,
                    arrow = grid::arrow(length = grid::unit(0.12, "in"))) +
  ggplot2::coord_cartesian(xlim = c(0.6, 3.4), ylim = c(0.4, 3.6)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter10/error_components.pdf", p0, width = 7, height = 3.8)

coef_compare <- data.frame(
  estimator = rep(c("Pooled", "Between", "Random effects", "Fixed effects"), each = 2),
  regressor = rep(c("log(value)", "log(capital)"), 4),
  estimate = c(coef(pool)[2:3], coef(between)[2:3], coef(re_swar)[2:3], coef(fe)[1:2])
)
write.csv(coef_compare, "tables/chapter10/coefficient_comparison.csv", row.names = FALSE)

p1 <- ggplot2::ggplot(components, ggplot2::aes(component, variance)) +
  ggplot2::geom_col(width = 0.55) +
  ggplot2::labs(x = NULL, y = "Estimated conditional variance") +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter10/variance_components.pdf", p1, width = 6.5, height = 3.8)

p2 <- ggplot2::ggplot(coef_compare, ggplot2::aes(estimator, estimate, group = regressor, shape = regressor)) +
  ggplot2::geom_point(size = 2.7) + ggplot2::geom_line(ggplot2::aes(linetype = regressor)) +
  ggplot2::labs(x = NULL, y = "Slope estimate", shape = NULL, linetype = NULL) +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter10/coefficient_comparison.pdf", p2, width = 7, height = 4)

p3 <- ggplot2::ggplot(effects_table, ggplot2::aes(factor(firm), effect_manual)) +
  ggplot2::geom_col() + ggplot2::geom_hline(yintercept = 0) +
  ggplot2::labs(x = "Firm", y = "Predicted random effect") + ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter10/predicted_effects.pdf", p3, width = 7, height = 4)

level_growth <- data.frame(
  form = c("Logged levels", "First log differences"),
  firm_variance = c(sigma_alpha2, sigma_alpha2_d)
)
p4 <- ggplot2::ggplot(level_growth, ggplot2::aes(form, firm_variance)) +
  ggplot2::geom_col(width = 0.55) + ggplot2::labs(x = NULL, y = "Estimated firm-component variance") +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter10/level_growth_variance.pdf", p4, width = 6.5, height = 3.8)

# Conceptual theta continuum.
theta_grid <- seq(0, 1, length.out = 101)
theta_df <- data.frame(theta = theta_grid, pooling_weight = 1 - theta_grid, demeaning_weight = theta_grid)
p5 <- ggplot2::ggplot(theta_df, ggplot2::aes(theta)) +
  ggplot2::geom_line(ggplot2::aes(y = pooling_weight, linetype = "Raw mean retained"), linewidth = 0.7) +
  ggplot2::geom_line(ggplot2::aes(y = demeaning_weight, linetype = "Firm mean removed"), linewidth = 0.7) +
  ggplot2::geom_vline(xintercept = theta_manual, linetype = 3) +
  ggplot2::labs(x = expression(theta), y = "Transformation weight", linetype = NULL) +
  ggplot2::theme_minimal(base_size = 10)
ggplot2::ggsave("figures/chapter10/theta_continuum.pdf", p5, width = 7, height = 4)

writeLines(capture.output(sessionInfo()), "results/chapter10/sessionInfo.txt")
message("Chapter 10 RE benchmark reproduced successfully.")
