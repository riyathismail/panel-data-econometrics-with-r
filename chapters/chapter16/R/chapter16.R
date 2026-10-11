# Chapter 16 - Endogeneity, IV, and Dynamic Panel Models
# Run from the RStudio Project root: source("R/chapter16.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "plm", "ivreg", "sandwich", "lmtest")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter16", "results/chapter16", "figures/chapter16"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year)
stopifnot(nrow(dat) == 200L, dplyr::n_distinct(dat$firm) == 10L,
          dplyr::n_distinct(dat$year) == 20L, !anyDuplicated(dat[c("firm", "year")]),
          !anyNA(dat[c("invest", "value", "capital")]))

dat <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest = log(invest), lvalue = log(value), lcapital = log(capital),
    L_linvest = dplyr::lag(linvest, 1), L2_linvest = dplyr::lag(linvest, 2),
    dlinvest = linvest - dplyr::lag(linvest),
    dlvalue = lvalue - dplyr::lag(lvalue),
    dlcapital = lcapital - dplyr::lag(lcapital),
    L_dlinvest = dplyr::lag(dlinvest, 1)
  ) |>
  dplyr::ungroup()

# Dynamic level diagnostics ---------------------------------------------------
dyn_level <- dat |> dplyr::filter(!is.na(L_linvest))
stopifnot(nrow(dyn_level) == 190L)
pool_dyn <- stats::lm(linvest ~ L_linvest + lvalue + lcapital + factor(year), data = dyn_level)
twoway_dyn <- stats::lm(linvest ~ L_linvest + lvalue + lcapital + factor(firm) + factor(year), data = dyn_level)

bench_pool <- c(L_linvest = 0.939768, lvalue = 0.063556, lcapital = 0.008236)
bench_tw <- c(L_linvest = 0.593788, lvalue = 0.163462, lcapital = -0.050730)
stopifnot(max(abs(stats::coef(pool_dyn)[names(bench_pool)] - bench_pool)) < 1e-6)
stopifnot(max(abs(stats::coef(twoway_dyn)[names(bench_tw)] - bench_tw)) < 1e-6)
stopifnot(abs(summary(pool_dyn)$r.squared - 0.980992290635) < 1e-10)
stopifnot(abs(summary(twoway_dyn)$r.squared - 0.985171132073) < 1e-10)
stopifnot(max(abs(summary(pool_dyn)$coefficients[names(bench_pool), "Std. Error"] - c(0.032170,0.027101,0.019831))) < 1e-6)
stopifnot(max(abs(summary(twoway_dyn)$coefficients[names(bench_tw), "Std. Error"] - c(0.070868,0.078733,0.040566))) < 1e-6)

pdata <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
twoway_plm <- plm::plm(linvest ~ lag(linvest, 1) + lvalue + lcapital,
                        data = pdata, model = "within", effect = "twoways")
stopifnot(max(abs(unname(stats::coef(twoway_plm)) - unname(stats::coef(twoway_dyn)[c("L_linvest","lvalue","lcapital")]))) < 1e-8)

rho <- unname(coef(twoway_dyn)["L_linvest"])
long_run <- data.frame(
  quantity = c("half_life", "long_run_value", "long_run_capital"),
  estimate = c(log(.5)/log(rho), coef(twoway_dyn)["lvalue"]/(1-rho), coef(twoway_dyn)["lcapital"]/(1-rho))
)
stopifnot(abs(long_run$estimate[1] - 1.32982102534) < 1e-8)

# Dynamic growth + explicit period CR1 ---------------------------------------
dyn_growth <- dat |>
  dplyr::filter(stats::complete.cases(dlinvest, L_dlinvest, dlvalue, dlcapital))
stopifnot(nrow(dyn_growth) == 180L, dplyr::n_distinct(dyn_growth$year) == 18L)
growth_dyn <- stats::lm(dlinvest ~ L_dlinvest + dlvalue + dlcapital + factor(year), data = dyn_growth)
bench_growth <- c(L_dlinvest=-0.00557670224709, dlvalue=0.469851784723, dlcapital=-0.148094834524)
stopifnot(max(abs(coef(growth_dyn)[names(bench_growth)] - bench_growth)) < 1e-10)
stopifnot(abs(summary(growth_dyn)$r.squared - 0.488781260346) < 1e-10)

vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X))
  correction <- (G / (G - 1)) * ((n - 1) / (n - k))
  correction * bread %*% crossprod(S) %*% bread
}
V_period <- vcov_cr1(growth_dyn, dyn_growth$year)
keep <- names(bench_growth)
se_period <- sqrt(diag(V_period))[keep]
expected_se <- c(L_dlinvest=0.0982518202490, dlvalue=0.0957990017437, dlcapital=0.0543905494994)
stopifnot(max(abs(se_period - expected_se)) < 1e-10)

df_period <- 17
t_period <- coef(growth_dyn)[keep] / se_period
p_period <- 2 * stats::pt(abs(t_period), df = df_period, lower.tail = FALSE)
crit <- stats::qt(.975, df_period)
growth_report <- data.frame(
  term = keep, estimate = unname(coef(growth_dyn)[keep]), std.error = unname(se_period),
  statistic = unname(t_period), p.value = unname(p_period),
  conf.low = unname(coef(growth_dyn)[keep] - crit * se_period),
  conf.high = unname(coef(growth_dyn)[keep] + crit * se_period), df.reference = df_period
)
write.csv(growth_report, "tables/chapter16/dynamic_growth_period_cluster.csv", row.names = FALSE)

# Anderson-Hsiao IV -----------------------------------------------------------
iv_dat <- dat |>
  dplyr::filter(stats::complete.cases(dlinvest, L_dlinvest, L2_linvest, dlvalue, dlcapital))
stopifnot(nrow(iv_dat) == 180L)
ah <- ivreg::ivreg(
  dlinvest ~ L_dlinvest + dlvalue + dlcapital + factor(year) |
    L2_linvest + dlvalue + dlcapital + factor(year),
  data = iv_dat
)
stopifnot(abs(coef(ah)["L_dlinvest"] - 0.498599) < 1e-6)
stopifnot(abs(sqrt(diag(vcov(ah)))["L_dlinvest"] - 0.779410) < 1e-6)

first_stage_full <- lm(L_dlinvest ~ L2_linvest + dlvalue + dlcapital + factor(year), data = iv_dat)
first_stage_restricted <- lm(L_dlinvest ~ dlvalue + dlcapital + factor(year), data = iv_dat)
fs_test <- anova(first_stage_restricted, first_stage_full)
fs_F <- fs_test$F[2L]; fs_p <- fs_test$`Pr(>F)`[2L]
stopifnot(abs(fs_F - 2.10127038005) < 1e-9, abs(fs_p - 0.149146363683) < 1e-9)
iv_report <- data.frame(
  statistic = c("IV lag coefficient", "IV lag conventional SE", "IV lag p-value", "First-stage partial F", "First-stage p-value"),
  value = c(coef(ah)["L_dlinvest"], sqrt(diag(vcov(ah)))["L_dlinvest"],
            summary(ah)$coefficients["L_dlinvest","Pr(>|t|)"], fs_F, fs_p)
)
write.csv(iv_report, "tables/chapter16/anderson_hsiao_benchmark.csv", row.names = FALSE)

# Theoretical uncollapsed instrument-count audit ------------------------------
uncollapsed_count <- function(Tn, min_lag = 2L, max_lag = Inf) {
  total <- 0L
  for (t in 3:Tn) {
    available <- seq.int(2L, t - 1L)
    use <- available[available >= min_lag & available <= max_lag]
    total <- total + length(use)
  }
  total
}
counts <- data.frame(
  design = c("One variable, all lags 2+", "One variable, lags 2-3", "Three variables, lags 2-3"),
  instruments = c(uncollapsed_count(20,2,Inf), uncollapsed_count(20,2,3), 3*uncollapsed_count(20,2,3))
)
stopifnot(all(counts$instruments == c(171,35,105)))
write.csv(counts, "tables/chapter16/theoretical_instrument_counts.csv", row.names = FALSE)

# Formula evaluation within pgmm requires the plm namespace on the search path.
library(plm)
# Optional pgmm teaching runs -------------------------------------------------
# These models are deliberately NOT part of final case selection. Set
# RUN_CH16_GMM=1 to execute them in an R-enabled environment and inspect the
# actual instrument matrices/diagnostics.
instrument_audit <- function(pgmm_object) {
  W <- pgmm_object$W
  if (is.list(W) && length(W) > 0L && is.matrix(W[[1L]])) {
    Z <- do.call(rbind, W)
    return(c(columns = ncol(Z), rank = qr(Z)$rank))
  }
  c(columns = NA_real_, rank = NA_real_)
}
if (identical(Sys.getenv("RUN_CH16_GMM"), "1")) {
  tryCatch({
  ab1 <- plm::pgmm(
    linvest ~ lag(linvest, 1) + lvalue + lcapital |
      lag(linvest, 2:3) | lvalue + lcapital,
    data = pdata, effect = "twoways", model = "onestep",
    transformation = "d", collapse = TRUE
  )
  ab2 <- plm::pgmm(
    linvest ~ lag(linvest, 1) + lvalue + lcapital |
      lag(linvest, 2:3) | lvalue + lcapital,
    data = pdata, effect = "twoways", model = "twosteps",
    transformation = "d", collapse = TRUE
  )
  gmm_audit <- rbind(
    data.frame(model="difference_one_step", t(instrument_audit(ab1))),
    data.frame(model="difference_two_step", t(instrument_audit(ab2)))
  )
  write.csv(gmm_audit, "results/chapter16/gmm_instrument_audit.csv", row.names = FALSE)
  capture.output(summary(ab1, robust = TRUE), file = "results/chapter16/pgmm_difference_onestep.txt")
  capture.output(summary(ab2, robust = TRUE), file = "results/chapter16/pgmm_difference_twostep.txt")
  capture.output(plm::mtest(ab2, order = 1), file = "results/chapter16/pgmm_ar1.txt")
  capture.output(plm::mtest(ab2, order = 2), file = "results/chapter16/pgmm_ar2.txt")
  capture.output(plm::sargan(ab2, weights = "twosteps"), file = "results/chapter16/pgmm_sargan.txt")
  writeLines("GMM estimator completed; review instrument rank and small-N validity before interpretation.",
             "results/chapter16/GMM_TEACHING_STATUS.txt")
  }, error=function(e) {
    # Small-N instrument covariance can be singular. Preserve the actual failure;
    # never replace it with benchmark coefficients or a general-inverse estimate.
    writeLines(c("GMM ESTIMATOR FAILED: not a validated case estimator.",conditionMessage(e)),
               "results/chapter16/GMM_TEACHING_STATUS.txt")
    warning("Optional GMM could not be estimated: ",conditionMessage(e))
  })
} else {
  writeLines("Optional pgmm teaching run skipped. Set RUN_CH16_GMM=1 after reviewing the small-N warning.",
             "results/chapter16/GMM_TEACHING_RUN_SKIPPED.txt")
}

# Figures ---------------------------------------------------------------------
persist <- data.frame(
  estimator = factor(c("Pooled dynamic level", "Two-way FE level", "Dynamic growth", "Anderson-Hsiao IV"),
                     levels=c("Pooled dynamic level", "Two-way FE level", "Dynamic growth", "Anderson-Hsiao IV")),
  estimate = c(0.939768, 0.593788, -0.005576702, 0.498599),
  se = c(0.032170, 0.070868, 0.098251820, 0.779410)
)
persist$lo <- persist$estimate - 1.96*persist$se
persist$hi <- persist$estimate + 1.96*persist$se
p <- ggplot2::ggplot(persist, ggplot2::aes(estimator, estimate)) +
  ggplot2::geom_hline(yintercept=0, linewidth=.4) +
  ggplot2::geom_errorbar(ggplot2::aes(ymin=lo,ymax=hi), width=.15) +
  ggplot2::geom_point(size=2.4) + ggplot2::coord_flip() +
  ggplot2::labs(x=NULL,y="Lag/persistence estimate with 95% reference interval") +
  ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter16/persistence_comparison.pdf", p, width=7.2, height=4.4)

pc <- ggplot2::ggplot(counts, ggplot2::aes(reorder(design, instruments), instruments)) +
  ggplot2::geom_col() + ggplot2::geom_hline(yintercept=10, linetype=2) +
  ggplot2::coord_flip() + ggplot2::labs(x=NULL,y="Uncollapsed dynamic-instrument count") +
  ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter16/instrument_proliferation.pdf", pc, width=7.2, height=4.2)

# Simple vector diagrams use base graphics for low dependency overhead.
pdf("figures/chapter16/endogeneity_paths.pdf", width=7.2, height=4.2)
plot.new(); plot.window(xlim=c(0,10),ylim=c(0,6));
rect(0.8,2.3,3.2,3.7); text(2,3,"Regressor\\nX_it")
rect(6.8,2.3,9.2,3.7); text(8,3,"Outcome\\ny_it")
rect(3.8,4.3,6.2,5.5); text(5,4.9,"Time-varying\\nshock")
rect(3.8,0.5,6.2,1.7); text(5,1.1,"Firm effect\\nalpha_i")
arrows(3.2,3,6.8,3,length=.08); arrows(5,4.3,3,3.7,length=.08); arrows(5,4.3,7,3.7,length=.08)
arrows(5,1.7,3,2.3,length=.08); arrows(5,1.7,7,2.3,length=.08)
text(5,5.85,"FE removes the permanent firm effect, not the time-varying shock path",cex=.9)
dev.off()

pdf("figures/chapter16/dynamic_decision_map.pdf", width=7.4, height=5)
plot.new(); plot.window(xlim=c(0,10),ylim=c(0,8));
box <- function(x,y,w,h,txt){rect(x-w/2,y-h/2,x+w/2,y+h/2); text(x,y,txt,cex=.82)}
box(5,7.1,4.2,0.9,"Lagged dependent variable / endogenous regressor?")
box(2.5,5.4,3.2,0.9,"No: static panel workflow")
box(7.5,5.4,3.2,0.9,"Yes: state timing assumptions")
box(7.5,3.8,3.4,0.9,"External IV available and strong?")
box(4.1,2.1,3.3,0.9,"Use defensible IV / structural design")
box(8.3,2.1,3.1,0.9,"Internal-lag GMM plausible?")
box(8.3,0.7,3.4,0.9,"Restrict/collapse instruments; AR(1)/AR(2); J test")
arrows(4.2,6.7,3.2,5.85,length=.08); arrows(5.8,6.7,6.8,5.85,length=.08)
arrows(7.5,4.95,7.5,4.25,length=.08); arrows(6.6,3.4,4.9,2.55,length=.08); arrows(8,3.4,8.2,2.55,length=.08)
arrows(8.3,1.65,8.3,1.15,length=.08)
text(5,0.1,"Small N or too many/weak instruments -> do not select conventional dynamic GMM",cex=.86)
dev.off()

# Machine-readable core results and session capture ---------------------------
core <- data.frame(
  model=c("pooled_dynamic_level","twoway_FE_dynamic_level","dynamic_growth","Anderson_Hsiao_IV"),
  lag_estimate=c(coef(pool_dyn)["L_linvest"],coef(twoway_dyn)["L_linvest"],coef(growth_dyn)["L_dlinvest"],coef(ah)["L_dlinvest"]),
  observations=c(nobs(pool_dyn),nobs(twoway_dyn),nobs(growth_dyn),nobs(ah))
)
write.csv(core, "tables/chapter16/core_dynamic_results.csv", row.names=FALSE)
write.csv(long_run, "tables/chapter16/conditional_long_run_quantities.csv", row.names=FALSE)
writeLines(capture.output(sessionInfo()), "results/chapter16/sessionInfo.txt")
message("Chapter 16 static/dynamic-OLS/IV benchmarks reproduced. Optional pgmm teaching run status recorded.")
