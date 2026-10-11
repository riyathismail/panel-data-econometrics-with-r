# Chapter 19 - Panel Granger Causality and Panel Vector Autoregression
# Run from the RStudio Project root with: source("R/chapter19.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "plm", "lmtest", "sandwich", "panelvar")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in the renv environment: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter19", "results/chapter19", "figures/chapter19"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest = log(invest), lvalue = log(value), lcapital = log(capital),
    ginvest = linvest - dplyr::lag(linvest),
    gvalue = lvalue - dplyr::lag(lvalue),
    gcapital = lcapital - dplyr::lag(lcapital)
  ) |>
  dplyr::ungroup()
stopifnot(nrow(dat) == 200L, dplyr::n_distinct(dat$firm) == 10L, dplyr::n_distinct(dat$year) == 20L)
stopifnot(!anyDuplicated(dat[c("firm", "year")]))

growth <- dat |> dplyr::filter(stats::complete.cases(ginvest, gvalue, gcapital))
stopifnot(nrow(growth) == 190L, dplyr::n_distinct(growth$year) == 19L)
pdata_g <- plm::pdata.frame(growth, index = c("firm", "year"), drop.index = FALSE)

# -----------------------------------------------------------------------------
# Dumitrescu-Hurlin: native plm implementation and hard benchmark checks.
# Formula y ~ x means x Granger-predicts y.
# -----------------------------------------------------------------------------
pairs <- data.frame(
  predictor = c("ginvest", "ginvest", "gvalue", "gvalue", "gcapital", "gcapital"),
  predicted = c("gvalue", "gcapital", "ginvest", "gcapital", "ginvest", "gvalue")
)

dh_one <- function(pred, out, K) {
  f <- stats::as.formula(paste(out, "~", pred))
  z <- plm::pgrangertest(f, data = pdata_g, order = K, test = "Ztilde")
  w <- plm::pgrangertest(f, data = pdata_g, order = K, test = "Wbar")
  data.frame(lag = K, predictor = pred, predicted = out,
             Wbar = unname(w$statistic), Ztilde = unname(z$statistic),
             p_asymptotic = unname(z$p.value))
}

dh <- dplyr::bind_rows(lapply(1:nrow(pairs), function(i) dh_one(pairs$predictor[i], pairs$predicted[i], 1L)),
                       lapply(1:nrow(pairs), function(i) dh_one(pairs$predictor[i], pairs$predicted[i], 2L)))
expected_w <- c(1.2559732782,25.1527286237,0.7158818244,3.9111961513,3.0927450706,2.1426907442,
                2.9275517582,21.1869829023,1.6452815427,2.5815101749,3.2784588711,4.2648875260)
expected_z <- c(0.1754326903,41.2249786138,-0.7523296194,4.7365411626,3.3306161850,1.6986248064,
                0.5675553261,20.2115755294,-0.8119477823,0.1952738568,0.9450712717,2.0062995363)
stopifnot(max(abs(dh$Wbar - expected_w)) < 1e-8, max(abs(dh$Ztilde - expected_z)) < 1e-8)
readr::write_csv(dh, "tables/chapter19/dh_asymptotic_R.csv")

# -----------------------------------------------------------------------------
# Cross-language reproducible block-bootstrap sensitivity.
# The 1,000 synchronous circular-block index sequences were frozen once using
# PCG64 seed 1907 and stored as 1-based indices. This avoids RNG differences
# between R and Python changing the textbook Monte Carlo benchmark.
# -----------------------------------------------------------------------------
boot_idx <- as.matrix(readr::read_csv("reproducibility/bootstrap_block2_indices.csv", show_col_types = FALSE))
stopifnot(nrow(boot_idx) == 1000L, ncol(boot_idx) == 18L)

wald_k1 <- function(y, x) {
  dd <- data.frame(y = y[-1], Ly = y[-length(y)], Lx = x[-length(x)])
  fit <- stats::lm(y ~ Ly + Lx, data = dd)
  unname(coef(fit)["Lx"]^2 / vcov(fit)["Lx", "Lx"])
}

bootstrap_pair <- function(pred, out) {
  spl <- split(growth, growth$firm)
  pars <- lapply(spl, function(d) coef(stats::lm(d[[out]][-1] ~ d[[out]][-nrow(d)])))
  resids <- sapply(spl, function(d) residuals(stats::lm(d[[out]][-1] ~ d[[out]][-nrow(d)])))
  initial <- vapply(spl, function(d) d[[out]][1], numeric(1))
  xpaths <- lapply(spl, function(d) d[[pred]])
  obs <- mean(vapply(seq_along(spl), function(j) wald_k1(spl[[j]][[out]], xpaths[[j]]), numeric(1)))
  wb <- numeric(nrow(boot_idx))
  for (b in seq_len(nrow(boot_idx))) {
    rb <- resids[boot_idx[b, ], , drop = FALSE]
    wi <- numeric(length(spl))
    for (j in seq_along(spl)) {
      yy <- numeric(19); yy[1] <- initial[j]
      for (tt in 2:19) yy[tt] <- pars[[j]][1] + pars[[j]][2] * yy[tt - 1] + rb[tt - 1, j]
      wi[j] <- wald_k1(yy, xpaths[[j]])
    }
    wb[b] <- mean(wi)
  }
  exc <- sum(wb >= obs)
  c(exceedances = exc, p_block2 = (1 + exc) / 1001)
}
boot <- dplyr::bind_rows(lapply(seq_len(nrow(pairs)), function(i) {
  z <- bootstrap_pair(pairs$predictor[i], pairs$predicted[i])
  data.frame(predictor = pairs$predictor[i], predicted = pairs$predicted[i],
             exceedances = z[1], p_block2 = z[2])
}))
expected_boot <- c(0.351648351648,0.000999000999,0.729270729271,0.010989010989,0.016983016983,0.082917082917)
stopifnot(max(abs(boot$p_block2 - expected_boot)) < 1e-12)
readr::write_csv(boot, "tables/chapter19/dh_block_bootstrap_R.csv")

# -----------------------------------------------------------------------------
# Homogeneous two-way FE PVAR: transparent equation-by-equation implementation.
# -----------------------------------------------------------------------------
pvar_dat <- growth |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    L1_ginvest = dplyr::lag(ginvest),
    L1_gvalue = dplyr::lag(gvalue),
    L1_gcapital = dplyr::lag(gcapital),
    L2_ginvest = dplyr::lag(ginvest, 2), L2_gvalue = dplyr::lag(gvalue, 2), L2_gcapital = dplyr::lag(gcapital, 2),
    L3_ginvest = dplyr::lag(ginvest, 3), L3_gvalue = dplyr::lag(gvalue, 3), L3_gcapital = dplyr::lag(gcapital, 3)
  ) |>
  dplyr::ungroup()
p1 <- pvar_dat |> dplyr::filter(stats::complete.cases(L1_ginvest, L1_gvalue, L1_gcapital))
stopifnot(nrow(p1) == 180L, dplyr::n_distinct(p1$year) == 18L)

vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X))
  (G/(G-1))*((n-1)/(n-k)) * bread %*% crossprod(S) %*% bread
}

rhs1 <- "L1_ginvest + L1_gvalue + L1_gcapital + factor(firm) + factor(year)"
mods <- list(
  ginvest = stats::lm(stats::as.formula(paste("ginvest ~", rhs1)), data = p1),
  gvalue = stats::lm(stats::as.formula(paste("gvalue ~", rhs1)), data = p1),
  gcapital = stats::lm(stats::as.formula(paste("gcapital ~", rhs1)), data = p1)
)
lag_names <- c("L1_ginvest", "L1_gvalue", "L1_gcapital")
A1 <- do.call(rbind, lapply(mods, function(m) coef(m)[lag_names]))
expected_A1 <- matrix(c(-0.043297119,-0.055458818,-0.131212118,
                         0.137447534,-0.220983928,-0.087350122,
                         0.327179914,0.379884371,0.133995235), nrow = 3, byrow = TRUE)
stopifnot(max(abs(A1 - expected_A1)) < 1e-8)

coef_tab <- dplyr::bind_rows(lapply(names(mods), function(eq) {
  m <- mods[[eq]]; V <- vcov_cr1(m, p1$year)
  dplyr::bind_rows(lapply(lag_names, function(nm) {
    se <- sqrt(V[nm,nm]); t <- coef(m)[nm]/se
    data.frame(equation=eq, lagged_predictor=sub("L1_", "", nm), coefficient=coef(m)[nm],
               period_cluster_se=se, t_df17=t, p_df17=2*stats::pt(abs(t),df=17,lower.tail=FALSE))
  }))
}))
readr::write_csv(coef_tab, "tables/chapter19/pvar_coefficients_R.csv")

# Common-sample AIC/BIC/HQ. Gaussian constants are retained to match the book.
ic_sample <- pvar_dat |> dplyr::filter(year >= 2010)
info <- function(m) {
  n <- stats::nobs(m); k <- length(coef(m)); ssr <- sum(residuals(m)^2)
  c(AIC = 1 + log(2*pi) + log(ssr/n) + 2*k/n,
    BIC = 1 + log(2*pi) + log(ssr/n) + log(n)*k/n,
    HQ = 1 + log(2*pi) + log(ssr/n) + 2*log(log(n))*k/n)
}
ic <- dplyr::bind_rows(lapply(1:3, function(L) {
  lagvars <- unlist(lapply(1:L, function(j) paste0("L", j, "_", c("ginvest","gvalue","gcapital"))))
  vals <- sapply(c("ginvest","gvalue","gcapital"), function(y) {
    m <- stats::lm(stats::as.formula(paste(y, "~", paste(c(lagvars,"factor(firm)","factor(year)"), collapse=" + "))), data=ic_sample)
    info(m)
  })
  data.frame(lag=L, AIC=mean(vals["AIC",]), BIC=mean(vals["BIC",]), HQ=mean(vals["HQ",]))
}))
expected_ic <- matrix(c(-0.896244935,-0.358089518,-0.677718665,
                        -0.910101593,-0.314286666,-0.668161793,
                        -0.918685315,-0.265210879,-0.653331986), nrow=3, byrow=TRUE)
stopifnot(max(abs(as.matrix(ic[,c("AIC","BIC","HQ")]) - expected_ic)) < 1e-8)
readr::write_csv(ic, "tables/chapter19/lag_criteria_R.csv")

# Stability and residual innovation covariance.
roots <- eigen(A1)$values
stopifnot(max(Mod(roots)) < 1)
readr::write_csv(data.frame(real=Re(roots), imag=Im(roots), modulus=Mod(roots)), "tables/chapter19/pvar_roots_R.csv")
E <- do.call(cbind, lapply(mods, residuals))
Sigma <- crossprod(E) / nrow(E)
expected_Sigma <- matrix(c(0.03646142,0.00670034,-0.00428890,
                           0.00670034,0.01438887,0.00113767,
                          -0.00428890,0.00113767,0.02795922),3,3,byrow=TRUE)
stopifnot(max(abs(Sigma-expected_Sigma)) < 1e-8)
utils::write.csv(Sigma, "tables/chapter19/residual_covariance_R.csv")

# Explicit generalized IRF. This is reduced-form and order invariant, not structural.
girf_one <- function(A, Sigma, h, shock) {
  e <- diag(nrow(A))[,shock]
  (A %^% h) %*% Sigma %*% e / sqrt(Sigma[shock,shock])
}
# local matrix-power operator
`%^%` <- function(A, h) {
  if (h == 0) return(diag(nrow(A)))
  out <- diag(nrow(A)); for (j in seq_len(h)) out <- out %*% A; out
}
girf_rows <- list(); r <- 1L
for (h in 0:8) for (s in 1:3) {
  z <- girf_one(A1, Sigma, h, s)
  for (j in 1:3) { girf_rows[[r]] <- data.frame(horizon=h,response=c("ginvest","gvalue","gcapital")[j],shock=c("ginvest","gvalue","gcapital")[s],girf=z[j]); r <- r+1L }
}
girf <- dplyr::bind_rows(girf_rows)
readr::write_csv(girf, "results/chapter19/generalized_irf_R.csv")

# Generalized FEVD, normalized across innovations within each response.
gfevd <- function(A, Sigma, H=5) {
  m <- nrow(A); raw <- matrix(0,m,m)
  for (j in 1:m) {
    ej <- diag(m)[,j]
    den <- 0
    for (s in 0:(H-1)) { As <- A %^% s; den <- den + as.numeric(t(ej)%*%As%*%Sigma%*%t(As)%*%ej) }
    for (k in 1:m) {
      ek <- diag(m)[,k]; num <- 0
      for (s in 0:(H-1)) { As <- A %^% s; num <- num + as.numeric(t(ej)%*%As%*%Sigma%*%ek)^2 }
      raw[j,k] <- num / Sigma[k,k] / den
    }
  }
  raw / rowSums(raw)
}
G5 <- gfevd(A1,Sigma,5)
expected_G5 <- matrix(c(0.8930355167,0.0798915617,0.0270729216,
                        0.1053024441,0.8692414185,0.0254561374,
                        0.1564016680,0.1120443705,0.7315539615),3,3,byrow=TRUE)
stopifnot(max(abs(G5-expected_G5)) < 1e-8)
utils::write.csv(G5, "tables/chapter19/generalized_fevd_h5_R.csv")

# Residual diagnostics.
diag_rows <- lapply(seq_along(mods), function(j) {
  tmp <- p1[,c("firm","year")]; tmp$resid <- E[,j]
  rho <- tmp |> dplyr::group_by(firm) |> dplyr::arrange(year,.by_group=TRUE) |>
    dplyr::summarise(rho=stats::cor(resid[-1],resid[-dplyr::n()]),.groups="drop")
  M <- stats::xtabs(resid ~ year + firm, data=tmp); C <- stats::cor(M); u <- C[upper.tri(C)]
  Tn <- nrow(M); N <- ncol(M); CD <- sqrt(2*Tn/(N*(N-1))) * sum(u)
  data.frame(equation=names(mods)[j],mean_within_rho1=mean(rho$rho),mean_pair_corr=mean(u),mean_abs_pair_corr=mean(abs(u)),CD=CD,p_CD=2*stats::pnorm(abs(CD),lower.tail=FALSE))
})
diag <- dplyr::bind_rows(diag_rows)
readr::write_csv(diag, "tables/chapter19/residual_diagnostics_R.csv")

# Optional package-native FE-PVAR cross-check. Period dummies are exogenous controls.
# This does not replace the transparent equation-by-equation benchmark above.
panelvar_dat <- as.data.frame(growth)
for (yy in 2009:2025) panelvar_dat[[paste0("T",yy)]] <- as.integer(panelvar_dat$year == yy)
time_controls <- paste0("T",2009:2025)
pv_fe <- panelvar::pvarfeols(dependent_vars=c("ginvest","gvalue","gcapital"), lags=1,
                             exog_vars=time_controls, transformation="demean",
                             data=panelvar_dat, panel_identifier=c("firm","year"))
writeLines(capture.output(summary(pv_fe)), "results/chapter19/panelvar_pvarfeols_summary.txt")
writeLines(capture.output(panelvar::stability(pv_fe)), "results/chapter19/panelvar_stability.txt")

# Guarded GMM template only: not used as the case-study estimator with N=10.
# panelvar::pvargmm supports first differences or forward orthogonal deviations,
# instrument collapsing, maximum lag depths, and optional system instruments.

# Publication figures ---------------------------------------------------------
lab <- c(ginvest="Investment growth",gvalue="Firm-value growth",gcapital="Capital-stock growth")
p_lag <- ggplot2::ggplot(ic, ggplot2::aes(lag)) +
  ggplot2::geom_line(ggplot2::aes(y=AIC,linetype="AIC")) + ggplot2::geom_point(ggplot2::aes(y=AIC)) +
  ggplot2::geom_line(ggplot2::aes(y=BIC,linetype="BIC")) + ggplot2::geom_point(ggplot2::aes(y=BIC)) +
  ggplot2::geom_line(ggplot2::aes(y=HQ,linetype="HQ")) + ggplot2::geom_point(ggplot2::aes(y=HQ)) +
  ggplot2::scale_x_continuous(breaks=1:3) + ggplot2::labs(x="Lag order p",y="Average information criterion",linetype=NULL) + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter19/lag_criteria.pdf",p_lag,width=6.8,height=4)

amat <- as.data.frame(as.table(A1)); names(amat) <- c("equation","predictor","coefficient")
amat$equation <- factor(amat$equation,levels=1:3,labels=c("Investment eq.","Firm-value eq.","Capital eq."))
amat$predictor <- factor(amat$predictor,levels=1:3,labels=c("L1 investment","L1 firm value","L1 capital"))
p_mat <- ggplot2::ggplot(amat,ggplot2::aes(predictor,equation,fill=coefficient)) + ggplot2::geom_tile() + ggplot2::geom_text(ggplot2::aes(label=sprintf("%.3f",coefficient)),size=3) + ggplot2::labs(x=NULL,y=NULL,fill="Coefficient") + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter19/pvar_matrix.pdf",p_mat,width=6.5,height=4.3)

rootdf <- data.frame(real=Re(roots),imag=Im(roots)); circle <- data.frame(a=seq(0,2*pi,length.out=400)); circle$x <- cos(circle$a); circle$y <- sin(circle$a)
p_root <- ggplot2::ggplot() + ggplot2::geom_path(data=circle,ggplot2::aes(x,y),linetype=2) + ggplot2::geom_hline(yintercept=0) + ggplot2::geom_vline(xintercept=0) + ggplot2::geom_point(data=rootdf,ggplot2::aes(real,imag),size=2.4) + ggplot2::coord_equal(xlim=c(-1.1,1.1),ylim=c(-1.1,1.1)) + ggplot2::labs(x="Real",y="Imaginary") + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter19/pvar_roots.pdf",p_root,width=5.1,height=5.1)

ig <- girf |> dplyr::filter(response=="ginvest") |> dplyr::mutate(shock=lab[shock])
p_irf <- ggplot2::ggplot(ig,ggplot2::aes(horizon,girf,linetype=shock,shape=shock)) + ggplot2::geom_hline(yintercept=0) + ggplot2::geom_line() + ggplot2::geom_point() + ggplot2::labs(x="Horizon",y="Response of investment growth",linetype=NULL,shape=NULL) + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter19/girf_investment.pdf",p_irf,width=6.8,height=4)

fd <- as.data.frame(G5); names(fd) <- names(lab); fd$response <- names(lab); fd <- tidyr::pivot_longer(fd,-response,names_to="shock",values_to="share"); fd$shock <- lab[fd$shock]; fd$response <- lab[fd$response]
p_fevd <- ggplot2::ggplot(fd,ggplot2::aes(response,100*share,fill=shock)) + ggplot2::geom_col() + ggplot2::labs(x=NULL,y="Normalized generalized FEVD (%)",fill=NULL) + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter19/gfevd_h5.pdf",p_fevd,width=6.8,height=4.2)

writeLines(capture.output(sessionInfo()), "results/chapter19/sessionInfo.txt")
message("Chapter 19 benchmark reproduced successfully.")
