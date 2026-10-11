# Chapter 21 - Structural Breaks, Parameter Stability, and Regime Changes
# Run from the RStudio Project root: source("R/chapter21.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "sandwich", "strucchange")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter21", "results/chapter21", "figures/chapter21"))
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
stopifnot(nrow(dat) == 200L, dplyr::n_distinct(dat$firm) == 10L, dplyr::n_distinct(dat$year) == 20L)
stopifnot(!anyDuplicated(dat[c("firm", "year")]))
short <- dat |>
  dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
stopifnot(nrow(short) == 190L, dplyr::n_distinct(short$year) == 19L)

vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X))
  correction <- (G / (G - 1)) * ((n - 1) / (n - k))
  correction * bread %*% crossprod(S) %*% bread
}

wald_F <- function(model, V, terms, df_denom) {
  b <- stats::coef(model); idx <- match(terms, names(b))
  if (anyNA(idx)) stop("Restriction term not found")
  q <- length(idx); bb <- b[idx]; VV <- V[idx, idx, drop = FALSE]
  W <- as.numeric(t(bb) %*% solve(VV, bb)); F <- W / q
  data.frame(F = F, df1 = q, df2 = df_denom,
             p.value = stats::pf(F, q, df_denom, lower.tail = FALSE))
}

stable <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data = short)
V_period <- vcov_cr1(stable, short$year)
stopifnot(abs(coef(stable)["dlvalue"] - 0.49570942) < 1e-7,
          abs(coef(stable)["dlcapital"] - (-0.08569261)) < 1e-7,
          abs(sqrt(V_period["dlvalue", "dlvalue"]) - 0.07433646) < 1e-7,
          abs(sqrt(V_period["dlcapital", "dlcapital"]) - 0.04192665) < 1e-7,
          abs(sum(residuals(stable)^2) - 6.654347013855) < 1e-9)

# Package cross-check only; published benchmark remains the explicit CR1 formula.
V_period_pkg <- sandwich::vcovCL(stable, cluster = short$year, type = "HC1", cadjust = TRUE)
utils::write.csv(V_period_pkg, "results/chapter21/vcovCL_period_crosscheck.csv")

fit_common_break <- function(data, first_post) {
  d <- data |>
    dplyr::mutate(
      post = as.integer(year >= first_post),
      value_post = post * dlvalue,
      capital_post = post * dlcapital
    )
  m <- stats::lm(
    dlinvest ~ dlvalue + dlcapital + value_post + capital_post + factor(year),
    data = d
  )
  V <- vcov_cr1(m, d$year)
  joint <- wald_F(m, V, c("value_post", "capital_post"), 18)
  bv <- coef(m)["value_post"]; bk <- coef(m)["capital_post"]
  Fv <- as.numeric(bv^2 / V["value_post", "value_post"])
  Fk <- as.numeric(bk^2 / V["capital_post", "capital_post"])
  data.frame(first_post_label = first_post, joint_F = joint$F,
             joint_pointwise_p = joint$p.value, value_change = bv, capital_change = bk,
             value_change_F = Fv, capital_change_F = Fk)
}

# Known split -----------------------------------------------------------------
short2020 <- short |>
  dplyr::mutate(post2020 = as.integer(year >= 2020),
                value_post2020 = post2020 * dlvalue,
                capital_post2020 = post2020 * dlcapital)
known2020 <- stats::lm(
  dlinvest ~ dlvalue + dlcapital + value_post2020 + capital_post2020 + factor(year),
  data = short2020
)
V_known <- vcov_cr1(known2020, short2020$year)
known_wald <- wald_F(known2020, V_known, c("value_post2020", "capital_post2020"), 18)
stopifnot(abs(coef(known2020)["dlvalue"] - 0.52001288) < 1e-7,
          abs(coef(known2020)["value_post2020"] - (-0.10989342)) < 1e-7,
          abs(coef(known2020)["dlcapital"] - (-0.08566676)) < 1e-7,
          abs(coef(known2020)["capital_post2020"] - (-0.00572443)) < 1e-7,
          abs(known_wald$F - 0.2142301453) < 1e-9,
          abs(known_wald$p.value - 0.8091910777) < 1e-9)

crit <- stats::qt(.975, df = 18)
known_table <- data.frame(
  regressor = c("dln(value)", "dln(capital)"),
  pre_slope = c(coef(known2020)["dlvalue"], coef(known2020)["dlcapital"]),
  post_slope = c(coef(known2020)["dlvalue"] + coef(known2020)["value_post2020"],
                 coef(known2020)["dlcapital"] + coef(known2020)["capital_post2020"]),
  change = c(coef(known2020)["value_post2020"], coef(known2020)["capital_post2020"]),
  change_se_period_CR1 = sqrt(diag(V_known))[c("value_post2020", "capital_post2020")]
)
known_table$ci_low <- known_table$change - crit * known_table$change_se_period_CR1
known_table$ci_high <- known_table$change + crit * known_table$change_se_period_CR1
write.csv(known_table, "tables/chapter21/known_break_2020.csv", row.names = FALSE)

# Classical SSR-only comparison, for teaching only.
ssr_r <- sum(residuals(stable)^2); ssr_u <- sum(residuals(known2020)^2)
F_classical <- ((ssr_r - ssr_u) / 2) / (ssr_u / df.residual(known2020))
stopifnot(abs(F_classical - 0.1026012258) < 1e-9)

# Unknown-date profile ---------------------------------------------------------
candidates <- 2012:2021
profile <- dplyr::bind_rows(lapply(candidates, function(b) fit_common_break(short, b)))
write.csv(profile, "tables/chapter21/unknown_break_profile.csv", row.names = FALSE)
stopifnot(abs(max(profile$joint_F) - 3.0277034001) < 1e-9,
          profile$first_post_label[which.max(profile$joint_F)] == 2012L,
          abs(max(profile$value_change_F) - 5.6800970577) < 1e-9,
          abs(max(profile$capital_change_F) - 1.2907064153) < 1e-9)

# Efficient bootstrap that uses the fixed publisher randomization matrix.
bootstrap_supwald <- function(stable_model, data, candidates, weights) {
  X0 <- model.matrix(stable_model); b0 <- coef(stable_model); e0 <- residuals(stable_model)
  fitted0 <- fitted(stable_model); years <- sort(unique(data$year)); G <- length(years)
  if (ncol(weights) != G) stop("Bootstrap weight columns do not match periods")
  cl_index <- match(data$year, years)
  B <- nrow(weights); n <- nrow(data)
  Ystar <- matrix(fitted0, B, n, byrow = TRUE) + weights[, cl_index] * matrix(e0, B, n, byrow = TRUE)

  one_candidate <- function(first_post) {
    post <- as.integer(data$year >= first_post)
    X <- model.matrix(~ dlvalue + dlcapital + I(post * dlvalue) + I(post * dlcapital) + factor(year), data = data)
    k <- ncol(X); bread <- solve(crossprod(X)); A <- bread %*% t(X)
    bet <- Ystar %*% t(A); E <- Ystar - bet %*% t(X)
    idx <- match(c("I(post * dlvalue)", "I(post * dlcapital)"), colnames(X))
    H <- bread[idx, , drop = FALSE]
    v11 <- v22 <- v12 <- numeric(B)
    for (g in years) {
      m <- data$year == g
      S <- E[, m, drop = FALSE] %*% X[m, , drop = FALSE]
      U <- S %*% t(H)
      v11 <- v11 + U[,1]^2; v22 <- v22 + U[,2]^2; v12 <- v12 + U[,1] * U[,2]
    }
    adj <- (G / (G - 1)) * ((n - 1) / (n - k)); v11 <- adj*v11; v22 <- adj*v22; v12 <- adj*v12
    bb1 <- bet[,idx[1]]; bb2 <- bet[,idx[2]]; det <- v11*v22 - v12^2
    W <- (v22*bb1^2 - 2*v12*bb1*bb2 + v11*bb2^2) / det
    cbind(joint = W/2, value = bb1^2/v11, capital = bb2^2/v22)
  }
  arr <- lapply(candidates, one_candidate)
  joint <- do.call(cbind, lapply(arr, function(z) z[,"joint"]))
  value <- do.call(cbind, lapply(arr, function(z) z[,"value"]))
  capital <- do.call(cbind, lapply(arr, function(z) z[,"capital"]))
  sup_joint <- apply(joint, 1, max); sup_value <- apply(value, 1, max); sup_capital <- apply(capital, 1, max)
  obs_joint <- max(profile$joint_F); obs_value <- max(profile$value_change_F); obs_capital <- max(profile$capital_change_F)
  list(
    joint_p = (1 + sum(sup_joint >= obs_joint)) / (B + 1),
    value_p = (1 + sum(sup_value >= obs_value)) / (B + 1),
    capital_p = (1 + sum(sup_capital >= obs_capital)) / (B + 1),
    joint_critical_95 = sort(sup_joint)[ceiling(.95 * B)],
    sup_joint = sup_joint
  )
}
weights <- as.matrix(readr::read_csv("reproducibility/bootstrap_weights_seed2107.csv", show_col_types = FALSE))
boot <- bootstrap_supwald(stable, short, candidates, weights)
stopifnot(abs(boot$joint_p - 0.3894) < 1e-12,
          abs(boot$value_p - 0.1438) < 1e-12,
          abs(boot$capital_p - 0.8754) < 1e-12,
          abs(boot$joint_critical_95 - 9.0832342931) < 1e-8)
write.csv(data.frame(B=nrow(weights), joint_p=boot$joint_p, value_p=boot$value_p,
                     capital_p=boot$capital_p, joint_critical_95=boot$joint_critical_95),
          "tables/chapter21/bootstrap_search_summary.csv", row.names = FALSE)

# Seven-period rolling slopes --------------------------------------------------
rolling_slopes <- function(data, width = 7L) {
  yrs <- sort(unique(data$year)); starts <- yrs[seq_len(length(yrs) - width + 1L)]
  dplyr::bind_rows(lapply(starts, function(s) {
    e <- s + width - 1L; d <- data[data$year >= s & data$year <= e, ]
    m <- lm(dlinvest ~ dlvalue + dlcapital + factor(year), data = d)
    data.frame(start=s, end=e, window=paste0(s,"-",e), beta_value=coef(m)["dlvalue"], beta_capital=coef(m)["dlcapital"], n=nobs(m))
  }))
}
rolling <- rolling_slopes(short, 7L)
write.csv(rolling, "tables/chapter21/rolling_slopes.csv", row.names = FALSE)
stopifnot(abs(min(rolling$beta_value)-0.3508356672) < 1e-6,
          abs(max(rolling$beta_value)-0.6778962705) < 1e-6,
          all(rolling$beta_value > 0),
          rolling$window[which.max(rolling$beta_value)] == "2015-2021")

# Residual-dispersion sensitivity ---------------------------------------------
period_mse <- short |>
  dplyr::mutate(resid = residuals(stable)) |>
  dplyr::group_by(year) |>
  dplyr::summarise(mean_squared_residual = mean(resid^2), .groups = "drop")
write.csv(period_mse, "tables/chapter21/period_residual_mse.csv", row.names = FALSE)
pre <- period_mse$mean_squared_residual[period_mse$year <= 2019]
post <- period_mse$mean_squared_residual[period_mse$year >= 2020]
welch <- t.test(pre, post, var.equal = FALSE)
stopifnot(abs(mean(pre)-0.04253294554) < 1e-10,
          abs(mean(post)-0.01875106823) < 1e-10,
          abs(unname(welch$statistic)-2.812639607) < 1e-8,
          abs(welch$p.value-0.01199603914) < 1e-8)

# Preview figures regenerated by R in production ------------------------------
# Conceptual taxonomy figure (non-empirical, but still code-generated).
taxonomy <- data.frame(
  x = c(1, 2, 3, 1.5, 2.5),
  y = c(2, 2, 2, 1, 1),
  label = c("Conditional mean\nintercept / slope breaks",
            "Conditional variance\nvolatility shifts",
            "Break timing\nknown / unknown dates",
            "Common timing\nsame date across firms",
            "Heterogeneous timing\nfirm-specific dates")
)
p_tax <- ggplot2::ggplot(taxonomy, ggplot2::aes(x, y, label = label)) +
  ggplot2::geom_label(size = 3.2) +
  ggplot2::coord_cartesian(xlim = c(.6, 3.4), ylim = c(.65, 2.35)) +
  ggplot2::theme_void()
ggplot2::ggsave("figures/chapter21/break_taxonomy.pdf", p_tax, width = 7.5, height = 4.0)

p_known <- ggplot2::ggplot(tidyr::pivot_longer(known_table, c(pre_slope, post_slope), names_to="regime", values_to="estimate"),
                           ggplot2::aes(regressor, estimate, shape=regime, group=regime)) +
  ggplot2::geom_point(size=2.5, position=ggplot2::position_dodge(width=.25)) +
  ggplot2::geom_hline(yintercept=0, linewidth=.3) + ggplot2::theme_minimal(base_size=10) +
  ggplot2::labs(x=NULL,y="Slope estimate",shape=NULL)
ggplot2::ggsave("figures/chapter21/known_break_coefficients.pdf", p_known, width=7, height=4.2)

p_sup <- ggplot2::ggplot(profile, ggplot2::aes(first_post_label, joint_F)) +
  ggplot2::geom_line() + ggplot2::geom_point() +
  ggplot2::geom_hline(yintercept=boot$joint_critical_95, linetype=2) +
  ggplot2::theme_minimal(base_size=10) + ggplot2::labs(x="Candidate first-post teaching label", y="Period-clustered joint F")
ggplot2::ggsave("figures/chapter21/supwald_profile.pdf", p_sup, width=7.2, height=4.2)

p_roll <- ggplot2::ggplot(tidyr::pivot_longer(rolling, c(beta_value,beta_capital), names_to="slope", values_to="estimate"),
                          ggplot2::aes(end,estimate,linetype=slope,shape=slope)) + ggplot2::geom_line() + ggplot2::geom_point() +
  ggplot2::geom_hline(yintercept=0,linewidth=.3) + ggplot2::theme_minimal(base_size=10) +
  ggplot2::labs(x="Window ending teaching label",y="Seven-period rolling slope",linetype=NULL,shape=NULL)
ggplot2::ggsave("figures/chapter21/rolling_slopes.pdf", p_roll, width=7.5, height=4.3)

p_var <- ggplot2::ggplot(period_mse,ggplot2::aes(year,mean_squared_residual)) + ggplot2::geom_line() + ggplot2::geom_point() +
  ggplot2::geom_vline(xintercept=2020,linetype=2) + ggplot2::theme_minimal(base_size=10) +
  ggplot2::labs(x="Teaching-period label",y="Mean squared residual across firms")
ggplot2::ggsave("figures/chapter21/residual_dispersion.pdf", p_var, width=7.3, height=4)

# Optional strucchange example is deliberately not run on stacked panel rows.
writeLines(capture.output(sessionInfo()), "results/chapter21/sessionInfo.txt")
message("Chapter 21 benchmark reproduced successfully.")
