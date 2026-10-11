
cips_zero <- function(x, lags=0L, type="drift", model="cmg") {
  stopifnot(lags==0L, type=="drift", model=="cmg")
  idx <- plm::index(x)
  z <- data.frame(value=as.numeric(x), firm=idx[[1]], year=idx[[2]])
  stopifnot(all(is.finite(z$value)), !anyDuplicated(z[c("firm","year")]),
            all(table(z$firm,z$year)==1L))
  years <- sort(unique(as.numeric(as.character(z$year))))
  stopifnot(all(diff(years)==1))
  W <- as.matrix(stats::xtabs(value ~ year + firm, data=z))
  bar <- rowMeans(W)
  tstats <- apply(W,2,function(y) {
    reg <- data.frame(dy=diff(y),ly=head(y,-1),
                      lybar=head(bar,-1),dybar=diff(bar))
    unname(summary(stats::lm(dy~ly+lybar+dybar,data=reg))$coefficients['ly','t value'])
  })
  stopifnot(all(is.finite(tstats)))
  stat <- mean(tstats)
  # Preserve the bounded/interpolated critical-value report as text.
  critical_report <- getFromNamespace('critvals.cips','plm')(
    stat=stat,n=ncol(W),T.=nrow(W),type=type,truncated=FALSE)
  list(method='Direct cross-section augmented DF(0), intercept, untruncated',
       statistic=c(CIPS=stat),individual_t=tstats,
       critical_value_p_report=critical_report,
       panel_dimensions=c(N=ncol(W),T=nrow(W)),
       critical_T_convention="Original observed time dimension; CADF uses T-1 regression rows")
}

# Chapter 15 - Complete Integrated R/RStudio Workflow
# Reusable functions for the targets pipeline.

assert_packages <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Install required packages in the renv environment: ", paste(missing, collapse = ", "))
  invisible(TRUE)
}

sha256_file <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)

read_validate_panel <- function(path) {
  dat <- readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::arrange(firm, year)
  required <- c("firm", "year", "invest", "value", "capital")
  stopifnot(
    identical(names(dat), required),
    nrow(dat) == 200L,
    dplyr::n_distinct(dat$firm) == 10L,
    dplyr::n_distinct(dat$year) == 20L,
    !anyDuplicated(dat[c("firm", "year")]),
    !anyNA(dat[required]),
    all(dat$invest > 0), all(dat$value > 0), all(dat$capital > 0)
  )
  counts <- table(dat$firm)
  stopifnot(length(counts) == 10L, all(counts == 20L))
  dat
}

transform_panel <- function(dat) {
  out <- dat |>
    dplyr::group_by(firm) |>
    dplyr::mutate(
      linvest = log(invest),
      lvalue = log(value),
      lcapital = log(capital),
      dlinvest = linvest - dplyr::lag(linvest),
      dlvalue = lvalue - dplyr::lag(lvalue),
      dlcapital = lcapital - dplyr::lag(lcapital),
      ginvest_pct = 100 * dlinvest,
      gvalue_pct = 100 * dlvalue,
      gcapital_pct = 100 * dlcapital
    ) |>
    dplyr::ungroup()
  first_period <- min(out$year)
  stopifnot(
    all(is.na(out$dlinvest[out$year == first_period])),
    all(is.na(out$dlvalue[out$year == first_period])),
    all(is.na(out$dlcapital[out$year == first_period])),
    sum(stats::complete.cases(out[c("dlinvest", "dlvalue", "dlcapital")])) == 190L
  )
  out
}

stationarity_stage <- function(dat) {
  pdata <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
  short <- dat |> dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
  pdata_d <- plm::pdata.frame(short, index = c("firm", "year"), drop.index = FALSE)
  stopifnot(plm::is.pbalanced(pdata), plm::is.pbalanced(pdata_d))
  list(
    first_generation_levels = list(
      linvest = plm::purtest(pdata$linvest, test = "madwu", exo = "intercept", lags = "SIC", pmax = 2),
      lvalue = plm::purtest(pdata$lvalue, test = "madwu", exo = "intercept", lags = "SIC", pmax = 2),
      lcapital = plm::purtest(pdata$lcapital, test = "madwu", exo = "intercept", lags = "SIC", pmax = 2)
    ),
    cips_levels = list(
      linvest = cips_zero(pdata$linvest, lags = 0L, type = "drift", model = "cmg"),
      lvalue = cips_zero(pdata$lvalue, lags = 0L, type = "drift", model = "cmg"),
      lcapital = cips_zero(pdata$lcapital, lags = 0L, type = "drift", model = "cmg")
    ),
    cips_differences = list(
      dlinvest = cips_zero(pdata_d$dlinvest, lags = 0L, type = "drift", model = "cmg"),
      dlvalue = cips_zero(pdata_d$dlvalue, lags = 0L, type = "drift", model = "cmg"),
      dlcapital = cips_zero(pdata_d$dlcapital, lags = 0L, type = "drift", model = "cmg")
    )
  )
}

estimate_candidates <- function(dat) {
  pdata <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
  short <- dat |> dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
  pdata_d <- plm::pdata.frame(short, index = c("firm", "year"), drop.index = FALSE)
  models <- list(
    pool_level_lm = stats::lm(linvest ~ lvalue + lcapital, data = dat),
    firm_level_lm = stats::lm(linvest ~ lvalue + lcapital + factor(firm), data = dat),
    time_level_lm = stats::lm(linvest ~ lvalue + lcapital + factor(year), data = dat),
    twoway_level_lm = stats::lm(linvest ~ lvalue + lcapital + factor(firm) + factor(year), data = dat),
    pool_level = plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "pooling"),
    firm_fe = plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "within", effect = "individual"),
    twoway_fe = plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "within", effect = "twoways"),
    re_level = plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "random", effect = "individual", random.method = "swar"),
    growth_pool = stats::lm(dlinvest ~ dlvalue + dlcapital, data = short),
    growth_firm = stats::lm(dlinvest ~ dlvalue + dlcapital + factor(firm), data = short),
    growth_period = stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data = short),
    growth_both = stats::lm(dlinvest ~ dlvalue + dlcapital + factor(firm) + factor(year), data = short),
    pdata = pdata,
    pdata_d = pdata_d,
    short = short
  )
  # Cross-engine coefficient checks.
  stopifnot(isTRUE(all.equal(unname(coef(models$pool_level_lm)), unname(coef(models$pool_level)), tolerance = 1e-10)))
  stopifnot(abs(coef(models$growth_period)["dlvalue"] - 0.495709423973) < 1e-10)
  stopifnot(abs(coef(models$growth_period)["dlcapital"] - (-0.0856926114420)) < 1e-10)
  models
}

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

nested_f <- function(restricted, unrestricted) {
  a <- stats::anova(restricted, unrestricted)
  data.frame(
    F = a$F[2],
    df1 = a$Df[2],
    df2 = stats::df.residual(unrestricted),
    p.value = a$`Pr(>F)`[2]
  )
}

selection_stage <- function(models, dat) {
  f_pool_fe <- nested_f(models$pool_level_lm, models$firm_level_lm)
  f_growth_firm <- nested_f(models$growth_pool, models$growth_firm)
  f_growth_period <- nested_f(models$growth_pool, models$growth_period)
  f_firm_given_period <- nested_f(models$growth_period, models$growth_both)
  f_period_given_firm <- nested_f(models$growth_firm, models$growth_both)
  lm_bp <- plm::plmtest(models$pool_level, effect = "individual", type = "bp")
  hausman <- plm::phtest(models$firm_fe, models$re_level)

  dat2 <- dat |>
    dplyr::group_by(firm) |>
    dplyr::mutate(mean_lvalue = mean(lvalue), mean_lcapital = mean(lcapital)) |>
    dplyr::ungroup()
  mundlak <- stats::lm(linvest ~ lvalue + lcapital + mean_lvalue + mean_lcapital + factor(year), data = dat2)
  V_mundlak <- vcov_2way_cr1(mundlak, dat2$firm, dat2$year)
  idx <- match(c("mean_lvalue", "mean_lcapital"), names(coef(mundlak)))
  b <- coef(mundlak)[idx]; V <- V_mundlak[idx, idx, drop = FALSE]
  W <- as.numeric(t(b) %*% solve(V, b)); pW <- stats::pchisq(W, df = 2, lower.tail = FALSE)

  # Published benchmark assertions.
  stopifnot(abs(f_pool_fe$F - 52.284645) < 1e-5)
  stopifnot(abs(unname(lm_bp$statistic) - 754.636424) < 1e-4)
  stopifnot(abs(unname(hausman$statistic) - 7.715151) < 1e-5)
  stopifnot(abs(W - 32.202709) < 1e-5)
  stopifnot(abs(f_growth_period$F - 4.844947) < 1e-5)
  stopifnot(abs(f_growth_firm$F - 0.194074) < 1e-5)
  stopifnot(abs(f_firm_given_period$F - 0.300909) < 1e-5)
  stopifnot(abs(f_period_given_firm$F - 4.681860) < 1e-5)

  dplyr::bind_rows(
    data.frame(test = "Pooled levels vs firm FE", statistic = f_pool_fe$F, df = sprintf("%d,%d", f_pool_fe$df1, f_pool_fe$df2), p.value = f_pool_fe$p.value),
    data.frame(test = "Pooled levels vs RE component", statistic = unname(lm_bp$statistic), df = "1", p.value = lm_bp$p.value),
    data.frame(test = "FE vs RE Hausman", statistic = unname(hausman$statistic), df = "2", p.value = hausman$p.value),
    data.frame(test = "Period-adjusted Mundlak means", statistic = W, df = "2", p.value = pW),
    data.frame(test = "Growth: firm effects vs pooled", statistic = f_growth_firm$F, df = sprintf("%d,%d", f_growth_firm$df1, f_growth_firm$df2), p.value = f_growth_firm$p.value),
    data.frame(test = "Growth: period effects vs pooled", statistic = f_growth_period$F, df = sprintf("%d,%d", f_growth_period$df1, f_growth_period$df2), p.value = f_growth_period$p.value),
    data.frame(test = "Growth: firm effects given period", statistic = f_firm_given_period$F, df = sprintf("%d,%d", f_firm_given_period$df1, f_firm_given_period$df2), p.value = f_firm_given_period$p.value),
    data.frame(test = "Growth: period effects given firm", statistic = f_period_given_firm$F, df = sprintf("%d,%d", f_period_given_firm$df1, f_period_given_firm$df2), p.value = f_period_given_firm$p.value)
  )
}

group_lr <- function(residuals, group) {
  e <- as.numeric(residuals); g <- as.factor(group); n <- length(e)
  lr <- n * log(sum(e^2) / n)
  for (lev in levels(g)) {
    r <- e[g == lev]; lr <- lr - length(r) * log(sum(r^2) / length(r))
  }
  df <- nlevels(g) - 1L
  c(statistic = lr, df = df, p.value = stats::pchisq(lr, df, lower.tail = FALSE))
}

ar1_aux <- function(residuals, firm) {
  z <- data.frame(firm = firm, resid = as.numeric(residuals)) |>
    dplyr::group_by(firm) |>
    dplyr::mutate(lag = dplyr::lag(resid)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(lag))
  m <- stats::lm(resid ~ 0 + lag, data = z)
  V <- vcov_cr1(m, z$firm)
  b <- coef(m)[1]; se <- sqrt(V[1,1]); t0 <- b/se
  list(model = m, slope = unname(b), se = unname(se), p0 = 2 * stats::pt(abs(t0), df = dplyr::n_distinct(z$firm)-1, lower.tail = FALSE), pairs = nrow(z))
}

cd_summary <- function(residuals, year, firm) {
  z <- data.frame(resid = as.numeric(residuals), year = year, firm = firm)
  W <- stats::xtabs(resid ~ year + firm, data = z)
  R <- stats::cor(W); N <- ncol(R); Tn <- nrow(W); vals <- R[upper.tri(R)]
  CD <- sqrt(2*Tn/(N*(N-1))) * sum(vals)
  c(mean.rho = mean(vals), mean.abs.rho = mean(abs(vals)), CD = CD,
    p.value = 2 * stats::pnorm(abs(CD), lower.tail = FALSE))
}

jb_moment <- function(e) {
  e <- as.numeric(e); z <- e - mean(e); n <- length(e); m2 <- mean(z^2)
  S <- mean(z^3) / m2^(3/2); K <- mean(z^4) / m2^2
  JB <- n/6 * (S^2 + (K-3)^2/4)
  c(statistic = JB, p.value = stats::pchisq(JB, 2, lower.tail = FALSE))
}

diagnostic_stage <- function(models) {
  m <- models$growth_period; short <- models$short
  hfirm <- group_lr(residuals(m), short$firm)
  hperiod <- group_lr(residuals(m), short$year)
  ar <- ar1_aux(residuals(m), short$firm)
  cd <- cd_summary(residuals(m), short$year, short$firm)
  cd["p.value"] <- NA_real_ # CD descriptive after complete period effects
  reset <- lmtest::resettest(m, power = 2:3, type = "fitted")
  jb <- jb_moment(residuals(m))
  stopifnot(abs(hfirm["statistic"] - 17.795230) < 1e-5)
  stopifnot(abs(hperiod["statistic"] - 39.085475) < 1e-5)
  stopifnot(abs(ar$slope - (-0.068979)) < 1e-5)
  stopifnot(abs(cd["CD"] - (-3.086843)) < 1e-5)
  stopifnot(abs(unname(reset$statistic) - 0.487666) < 1e-5)
  stopifnot(abs(jb["statistic"] - 5.104829) < 1e-5)
  data.frame(
    diagnostic = c("Firm groupwise variance LR", "Period groupwise variance LR", "Residual AR(1) slope", "Pesaran CD (descriptive after period FE)", "Ramsey RESET F", "Jarque-Bera"),
    statistic = c(hfirm["statistic"], hperiod["statistic"], ar$slope, cd["CD"], unname(reset$statistic), jb["statistic"]),
    p.value = c(hfirm["p.value"], hperiod["p.value"], ar$p0, cd["p.value"], reset$p.value, jb["p.value"]),
    stringsAsFactors = FALSE
  )
}

final_inference_stage <- function(models) {
  m <- models$growth_period; short <- models$short
  V_firm <- vcov_cr1(m, short$firm)
  V_period <- vcov_cr1(m, short$year)
  V_2way <- vcov_2way_cr1(m, short$firm, short$year)
  report_terms <- function(V, df_ref, label) {
    keep <- c("dlvalue", "dlcapital"); b <- coef(m)[keep]; se <- sqrt(diag(V)[keep])
    tval <- b/se; crit <- stats::qt(.975, df_ref)
    data.frame(covariance = label, term = keep, estimate = unname(b), std.error = unname(se),
      statistic = unname(tval), p.value = 2*stats::pt(abs(tval), df_ref, lower.tail = FALSE),
      conf.low = unname(b-crit*se), conf.high = unname(b+crit*se), df.reference = df_ref)
  }
  out <- dplyr::bind_rows(
    report_terms(V_firm, 9, "Firm cluster"),
    report_terms(V_period, 18, "Period cluster"),
    report_terms(V_2way, 9, "Two-way cluster")
  )
  expected_se <- c(0.138414508506,0.0401240022053,0.0743364623111,0.0419266496362,0.120338033149,0.0412292913853)
  stopifnot(max(abs(out$std.error - expected_se)) < 1e-10)
  out
}

make_decision_ledger <- function() {
  data.frame(
    decision = c("Panel structure", "Stationarity", "Permanent firm heterogeneity in levels", "FE versus RE in levels", "Period effects in growth", "Additional firm intercepts after differencing", "Growth diagnostics", "Inference"),
    evidence = c(
      "10 firms x 20 teaching periods = 200 complete level observations; no missing panel cells",
      "Logged-level conclusions are specification-sensitive; first log differences provide the primary short-run branch",
      "F(9,188)=52.285, p<0.001",
      "Hausman chi-square(2)=7.715, p=0.0211; Mundlak chi-square(2)=32.203, p<0.001",
      "F(18,169)=4.845, p<0.001",
      "F(9,178)=0.194, p=0.995",
      "No detected first-order residual persistence or RESET failure; heteroskedasticity remains; post-period-effect CD is descriptive",
      "Period-clustered inference primary; two-way clustering sensitivity"
    ),
    consequence = c(
      "Treat the level data as a strongly balanced panel",
      "Use first log differences as the principal short-run specification; do not claim a long-run levels relation without cointegration",
      "Reject a common pooled level intercept",
      "Conditional on admissible levels, prefer correlated/two-way FE logic to conventional RE",
      "Include complete transition-period effects",
      "Do not add redundant firm growth intercepts",
      "Retain the growth conditional mean but use dependence-aware covariance",
      "Report period cluster as primary and two-way cluster as sensitivity"
    ),
    stringsAsFactors = FALSE
  )
}

make_final_reporting_table <- function(models, inference) {
  p <- inference[inference$covariance == "Period cluster", ]
  t <- inference[inference$covariance == "Two-way cluster", ]
  get <- function(df, term) df[df$term == term, ]
  pv <- get(p, "dlvalue"); pc <- get(p, "dlcapital"); tv <- get(t, "dlvalue"); tc <- get(t, "dlcapital")
  data.frame(
    Item = c("Delta log(value): estimate", "Standard error", "95% confidence interval",
             "Delta log(capital): estimate", "Standard error", "95% confidence interval",
             "Period effects", "Observations", "Firms", "Transition periods", "R-squared", "Adjusted R-squared"),
    `Period clustered` = c(sprintf("%.4f", pv$estimate), sprintf("%.4f", pv$std.error), sprintf("[%.4f, %.4f]",pv$conf.low,pv$conf.high),
      sprintf("%.4f", pc$estimate), sprintf("%.4f", pc$std.error), sprintf("[%.4f, %.4f]",pc$conf.low,pc$conf.high),
      "Yes", "190", "10", "19", sprintf("%.4f",summary(models$growth_period)$r.squared), sprintf("%.4f",summary(models$growth_period)$adj.r.squared)),
    `Two-way clustered` = c(sprintf("%.4f", tv$estimate), sprintf("%.4f", tv$std.error), sprintf("[%.4f, %.4f]",tv$conf.low,tv$conf.high),
      sprintf("%.4f", tc$estimate), sprintf("%.4f", tc$std.error), sprintf("[%.4f, %.4f]",tc$conf.low,tc$conf.high),
      "Yes", "190", "10", "19", sprintf("%.4f",summary(models$growth_period)$r.squared), sprintf("%.4f",summary(models$growth_period)$adj.r.squared)), check.names = FALSE
  )
}

export_stationarity <- function(x) {
  dir.create("results/chapter15", recursive = TRUE, showWarnings = FALSE)
  path <- "results/chapter15/stationarity_tests.txt"
  sections <- c(
    "===== FIRST-GENERATION LEVEL TESTS =====",
    unlist(lapply(names(x$first_generation_levels), function(nm) c(paste0("--- ", nm, " ---"), capture.output(print(x$first_generation_levels[[nm]]))))),
    "===== CIPS LEVEL TESTS =====",
    unlist(lapply(names(x$cips_levels), function(nm) c(paste0("--- ", nm, " ---"), capture.output(print(x$cips_levels[[nm]]))))),
    "===== CIPS FIRST-DIFFERENCE TESTS =====",
    unlist(lapply(names(x$cips_differences), function(nm) c(paste0("--- ", nm, " ---"), capture.output(print(x$cips_differences[[nm]])))))
  )
  writeLines(sections, path); path
}

export_tables <- function(selection, diagnostics, inference, ledger, final_table) {
  dir.create("tables/chapter15", recursive = TRUE, showWarnings = FALSE)
  paths <- c(
    "tables/chapter15/selection_tests.csv",
    "tables/chapter15/diagnostics.csv",
    "tables/chapter15/cluster_inference.csv",
    "tables/chapter15/decision_ledger.csv",
    "tables/chapter15/final_reporting_table.csv",
    "tables/chapter15/final_reporting_table.tex",
    "tables/chapter15/final_reporting_table.md"
  )
  utils::write.csv(selection, paths[1], row.names = FALSE)
  utils::write.csv(diagnostics, paths[2], row.names = FALSE)
  utils::write.csv(inference, paths[3], row.names = FALSE)
  utils::write.csv(ledger, paths[4], row.names = FALSE)
  utils::write.csv(final_table, paths[5], row.names = FALSE)
  modelsummary::datasummary_df(final_table, output = paths[6], title = "Final period-adjusted growth model")
  modelsummary::datasummary_df(final_table, output = paths[7], title = "Final period-adjusted growth model")
  paths
}

export_figures <- function(dat, ledger) {
  dir.create("figures/chapter15", recursive = TRUE, showWarnings = FALSE)
  # Integrated workflow.
  workflow <- data.frame(x = 1:8, y = 1,
    label = c("Import", "Audit", "Transform", "Stationarity", "Candidates", "Effects", "Diagnostics", "Inference / archive"))
  p1 <- ggplot2::ggplot(workflow, ggplot2::aes(x,y,label=label)) +
    ggplot2::geom_label(size=2.6) +
    ggplot2::geom_segment(data=data.frame(x=1:7,xend=2:8), ggplot2::aes(x=x,xend=xend,y=1,yend=1), inherit.aes=FALSE,
      arrow=grid::arrow(length=grid::unit(.07,"in")), linewidth=.3) +
    ggplot2::coord_cartesian(xlim=c(.6,8.4),ylim=c(.75,1.25)) + ggplot2::theme_void()
  ggplot2::ggsave("figures/chapter15/integrated_workflow.pdf", p1, width=7.2, height=2.0)

  # Sample accounting.
  sample <- data.frame(stage=c("Level panel","First log differences"), n=c(200,190))
  p2 <- ggplot2::ggplot(sample,ggplot2::aes(stage,n)) + ggplot2::geom_col(width=.55) +
    ggplot2::geom_text(ggplot2::aes(label=n),vjust=-.4) + ggplot2::coord_cartesian(ylim=c(0,220)) +
    ggplot2::labs(x=NULL,y="Observations") + ggplot2::theme_minimal(base_size=10)
  ggplot2::ggsave("figures/chapter15/sample_accounting.pdf",p2,width=5.8,height=3.5)

  # Decision ledger overview.
  d <- data.frame(step=seq_len(nrow(ledger)),decision=ledger$decision)
  p3 <- ggplot2::ggplot(d,ggplot2::aes(step,1,label=decision)) + ggplot2::geom_label(size=2.5) +
    ggplot2::geom_segment(data=data.frame(x=1:7,xend=2:8),ggplot2::aes(x=x,xend=xend,y=1,yend=1),inherit.aes=FALSE,
      arrow=grid::arrow(length=grid::unit(.06,"in")),linewidth=.3) + ggplot2::coord_cartesian(xlim=c(.6,8.4),ylim=c(.75,1.25)) + ggplot2::theme_void()
  ggplot2::ggsave("figures/chapter15/decision_ledger.pdf",p3,width=7.2,height=2.0)

  # Reproducibility package.
  pkg <- data.frame(x=c(1,2,3,1,2,3),y=c(2,2,2,1,1,1),label=c("Raw CSV + hash","R functions","targets pipeline","Tables / figures","renv.lock","Decision log + sessionInfo"))
  p4 <- ggplot2::ggplot(pkg,ggplot2::aes(x,y,label=label)) + ggplot2::geom_label(size=3.0) +
    ggplot2::coord_cartesian(xlim=c(.5,3.5),ylim=c(.55,2.45)) + ggplot2::theme_void()
  ggplot2::ggsave("figures/chapter15/reproducibility_package.pdf",p4,width=6.8,height=3.4)
  c("figures/chapter15/integrated_workflow.pdf","figures/chapter15/sample_accounting.pdf","figures/chapter15/decision_ledger.pdf","figures/chapter15/reproducibility_package.pdf")
}

write_data_hash <- function(hash) {
  path <- "results/chapter15/data_sha256.txt"; writeLines(hash,path); path
}

write_session_info <- function() {
  path <- "results/chapter15/sessionInfo.txt"; writeLines(capture.output(sessionInfo()),path); path
}

write_pipeline_manifest <- function(files) {
  files <- unique(files)
  stopifnot(all(file.exists(files)))
  out <- data.frame(file=files, sha256=vapply(files, sha256_file, character(1)), stringsAsFactors=FALSE)
  path <- "results/chapter15/output_manifest.csv"; utils::write.csv(out,path,row.names=FALSE); path
}
