# Chapter 13 - Robust Inference and Covariance Estimation for Panel Models
# Run from the RStudio Project root: source("R/chapter13.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "plm", "lmtest", "sandwich", "clubSandwich")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in the renv environment: ", paste(missing, collapse = ", "))
for (d in c("tables/chapter13", "results/chapter13", "figures/chapter13")) dir.create(d, recursive=TRUE, showWarnings=FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest=log(invest), lvalue=log(value), lcapital=log(capital),
    dlinvest=linvest-dplyr::lag(linvest), dlvalue=lvalue-dplyr::lag(lvalue), dlcapital=lcapital-dplyr::lag(lcapital)
  ) |>
  dplyr::ungroup()
stopifnot(nrow(dat)==200L, dplyr::n_distinct(dat$firm)==10L, dplyr::n_distinct(dat$year)==20L,
          !anyDuplicated(dat[c("firm","year")]), !anyNA(dat[c("invest","value","capital")]))
short <- dat |> dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
stopifnot(nrow(short)==190L)

# Coefficient estimators -------------------------------------------------------
level_lsdv <- stats::lm(linvest ~ lvalue + lcapital + factor(firm) + factor(year), data=dat)
short_lsdv <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data=short)
pdata_level <- plm::pdata.frame(dat, index=c("firm","year"), drop.index=FALSE)
pdata_short <- plm::pdata.frame(short, index=c("firm","year"), drop.index=FALSE)
level_plm <- plm::plm(linvest ~ lvalue + lcapital, data=pdata_level, model="within", effect="twoways")
short_plm <- plm::plm(dlinvest ~ dlvalue + dlcapital, data=pdata_short, model="within", effect="time")
stopifnot(max(abs(unname(coef(level_plm)) - unname(coef(level_lsdv)[c("lvalue","lcapital")]))) < 1e-10)
stopifnot(max(abs(unname(coef(short_plm)) - unname(coef(short_lsdv)[c("dlvalue","dlcapital")]))) < 1e-10)
stopifnot(max(abs(coef(level_lsdv)[c("lvalue","lcapital")] - c(0.328554135,0.076795861))) < 1e-8)
stopifnot(max(abs(coef(short_lsdv)[c("dlvalue","dlcapital")] - c(0.495709424,-0.085692611))) < 1e-8)

# Transparent covariance definitions -----------------------------------------
vcov_hc1 <- function(model) {
  X <- stats::model.matrix(model); e <- stats::residuals(model); n <- nrow(X); K <- ncol(X)
  bread <- solve(crossprod(X)); meat <- crossprod(X, X * as.numeric(e^2))
  (n/(n-K)) * bread %*% meat %*% bread
}
vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model); n <- nrow(X); K <- ncol(X)
  g <- factor(cluster); G <- nlevels(g)
  S <- rowsum(X * as.numeric(e), g, reorder=FALSE)
  bread <- solve(crossprod(X)); correction <- (G/(G-1))*((n-1)/(n-K))
  correction * bread %*% crossprod(S) %*% bread
}
vcov_2way_cr1 <- function(model, firm, period) {
  vcov_cr1(model, firm) + vcov_cr1(model, period) - vcov_cr1(model, interaction(firm, period, drop=TRUE))
}
vcov_pcse_teaching <- function(model, firm, period, diagonal=FALSE) {
  X <- stats::model.matrix(model); e <- stats::residuals(model); n <- nrow(X); K <- ncol(X)
  ids <- sort(unique(firm)); tt <- sort(unique(period))
  E <- xtabs(e ~ period + firm)
  E <- E[as.character(tt), as.character(ids), drop=FALSE]
  Sigma <- crossprod(E)/nrow(E)
  if (diagonal) Sigma <- diag(diag(Sigma))
  meat <- matrix(0, K, K)
  for (t in tt) {
    idx <- which(period == t); idx <- idx[order(firm[idx])]
    Xt <- X[idx,,drop=FALSE]
    meat <- meat + t(Xt) %*% Sigma %*% Xt
  }
  bread <- solve(crossprod(X))
  (n/(n-K)) * bread %*% meat %*% bread
}
vcov_dk_teaching <- function(model, period, maxlag=2L) {
  X <- stats::model.matrix(model); e <- stats::residuals(model); tt <- sort(unique(period)); Tn <- length(tt); K <- ncol(X)
  H <- do.call(rbind, lapply(tt, function(t) colSums(X[period==t,,drop=FALSE] * as.numeric(e[period==t]))))
  S <- crossprod(H)
  for (ell in seq_len(maxlag)) {
    w <- 1 - ell/(maxlag+1)
    G <- matrix(0,K,K)
    for (j in (ell+1):Tn) G <- G + tcrossprod(H[j,], H[j-ell,])
    S <- S + w*(G+t(G))
  }
  bread <- solve(crossprod(X))
  (Tn/(Tn-2)) * bread %*% S %*% bread
}

cov_set <- function(model, firm, period, slope_names, period_df) {
  V <- list(
    Ordinary=stats::vcov(model),
    HC1=vcov_hc1(model),
    `Firm cluster`=vcov_cr1(model, firm),
    `Period cluster`=vcov_cr1(model, period),
    `Two-way cluster`=vcov_2way_cr1(model, firm, period),
    `PCSE SUR`=vcov_pcse_teaching(model, firm, period, FALSE),
    `PCSE diagonal`=vcov_pcse_teaching(model, firm, period, TRUE),
    `Driscoll-Kraay`=vcov_dk_teaching(model, period, 2L)
  )
  refs <- c(Ordinary=stats::df.residual(model), HC1=stats::df.residual(model), `Firm cluster`=9,
            `Period cluster`=period_df, `Two-way cluster`=9, `PCSE SUR`=stats::df.residual(model),
            `PCSE diagonal`=stats::df.residual(model), `Driscoll-Kraay`=period_df)
  out <- do.call(rbind, lapply(names(V), function(nm) {
    VV <- V[[nm]]; b <- coef(model)[slope_names]; se <- sqrt(diag(VV)[slope_names]); tstat <- b/se
    data.frame(method=nm, term=slope_names, estimate=unname(b), std.error=unname(se), statistic=unname(tstat),
               p.value=2*stats::pt(abs(tstat),df=refs[[nm]],lower.tail=FALSE), df.reference=refs[[nm]], row.names=NULL)
  }))
  attr(out,"vcov") <- V
  out
}
level_covariance_table <- cov_set(level_lsdv, dat$firm, dat$year, c("lvalue","lcapital"), 19)
growth_covariance_table <- cov_set(short_lsdv, short$firm, short$year, c("dlvalue","dlcapital"), 18)

# Published benchmark assertions ---------------------------------------------
expected_level_se <- c(
  0.08624732,0.03445064, 0.08632267,0.03802849, 0.19091229,0.05155251, 0.07584544,0.04324475,
  0.18640931,0.05551219, 0.07705556,0.03294218, 0.08239968,0.03370493, 0.07504355,0.05167208)
expected_growth_se <- c(
  0.09991939,0.04839993, 0.10101111,0.04084024, 0.13841451,0.04012400, 0.07433646,0.04192665,
  0.12033803,0.04122929, 0.09608123,0.04154711, 0.09634394,0.04103903, 0.07778550,0.03429020)
stopifnot(max(abs(level_covariance_table$std.error-expected_level_se)) < 1e-7)
stopifnot(max(abs(growth_covariance_table$std.error-expected_growth_se)) < 1e-7)

# Cluster confidence intervals for the capital-growth coefficient.
cluster_ci <- function(tab, method) {
  z <- tab[tab$method==method & tab$term=="dlcapital",]
  crit <- stats::qt(.975,z$df.reference)
  data.frame(method=method, lower=z$estimate-crit*z$std.error, upper=z$estimate+crit*z$std.error)
}
growth_cluster_ci <- dplyr::bind_rows(lapply(c("Firm cluster","Period cluster","Two-way cluster"), function(m) cluster_ci(growth_covariance_table,m)))

# Native R package cross-checks -----------------------------------------------
# These are recorded separately because transformed-model degrees-of-freedom and finite-sample conventions can differ from the explicit expanded-design benchmark.
native <- list(
  level_arellano_firm = plm::vcovHC(level_plm, method="arellano", type="HC1", cluster="group"),
  level_arellano_time = plm::vcovHC(level_plm, method="arellano", type="HC1", cluster="time"),
  level_double_cluster = plm::vcovDC(level_plm, type="HC1"),
  level_pcse = plm::vcovBK(level_plm, type="HC1", cluster="time", diagonal=FALSE),
  level_pcse_diagonal = plm::vcovBK(level_plm, type="HC1", cluster="time", diagonal=TRUE),
  level_dk = plm::vcovSCC(level_plm, type="HC1", maxlag=2),
  growth_arellano_firm = plm::vcovHC(short_plm, method="arellano", type="HC1", cluster="group"),
  growth_arellano_time = plm::vcovHC(short_plm, method="arellano", type="HC1", cluster="time"),
  growth_double_cluster = plm::vcovDC(short_plm, type="HC1"),
  growth_pcse = plm::vcovBK(short_plm, type="HC1", cluster="time", diagonal=FALSE),
  growth_pcse_diagonal = plm::vcovBK(short_plm, type="HC1", cluster="time", diagonal=TRUE),
  growth_dk = plm::vcovSCC(short_plm, type="HC1", maxlag=2)
)
for (nm in names(native)) utils::write.csv(native[[nm]], file.path("results","chapter13",paste0(nm,".csv")))

# Few-cluster CR2/Satterthwaite sensitivity -----------------------------------
cr2_level_firm <- clubSandwich::coef_test(level_plm, vcov="CR2", cluster=dat$firm, test="Satterthwaite", coefs=c("lvalue","lcapital"))
cr2_growth_firm <- clubSandwich::coef_test(short_plm, vcov="CR2", cluster=short$firm, test="Satterthwaite", coefs=c("dlvalue","dlcapital"))
utils::write.csv(as.data.frame(cr2_level_firm), "results/chapter13/cr2_level_firm.csv", row.names=FALSE)
utils::write.csv(as.data.frame(cr2_growth_firm), "results/chapter13/cr2_growth_firm.csv", row.names=FALSE)

# Exports ---------------------------------------------------------------------
utils::write.csv(level_covariance_table, "tables/chapter13/level_covariance_sensitivity.csv", row.names=FALSE)
utils::write.csv(growth_covariance_table, "tables/chapter13/growth_covariance_sensitivity.csv", row.names=FALSE)
utils::write.csv(growth_cluster_ci, "tables/chapter13/growth_cluster_confidence_intervals.csv", row.names=FALSE)
writeLines(capture.output(sessionInfo()), "results/chapter13/sessionInfo.txt")

# Figures ---------------------------------------------------------------------
plot_se <- function(tab, terms, path, ylab) {
  p <- tab |> dplyr::filter(term %in% terms) |>
    ggplot2::ggplot(ggplot2::aes(method,std.error,shape=term,group=term)) +
    ggplot2::geom_point(size=2.2) + ggplot2::geom_line() +
    ggplot2::labs(x=NULL,y=ylab,shape=NULL) + ggplot2::theme_minimal(base_size=10) +
    ggplot2::theme(axis.text.x=ggplot2::element_text(angle=30,hjust=1))
  ggplot2::ggsave(path,p,width=7.1,height=4.2)
}
plot_se(level_covariance_table,c("lvalue","lcapital"),"figures/chapter13/se_level.pdf","Standard error")
plot_se(growth_covariance_table,c("dlvalue","dlcapital"),"figures/chapter13/se_growth.pdf","Standard error")

ci_methods <- c("Ordinary","HC1","Firm cluster","Period cluster","Two-way cluster","PCSE SUR","PCSE diagonal","Driscoll-Kraay")
ci_df <- growth_covariance_table |>
  dplyr::filter(term %in% c("dlvalue","dlcapital")) |>
  dplyr::mutate(critical=stats::qt(.975,df.reference), lower=estimate-critical*std.error, upper=estimate+critical*std.error,
                method=factor(method,levels=ci_methods))
pci <- ggplot2::ggplot(ci_df,ggplot2::aes(estimate,method,xmin=lower,xmax=upper,shape=term)) +
  ggplot2::geom_vline(xintercept=0,linewidth=.35) + ggplot2::geom_errorbarh(height=.2,position=ggplot2::position_dodge(width=.4)) +
  ggplot2::geom_point(position=ggplot2::position_dodge(width=.4),size=2) +
  ggplot2::labs(x="Coefficient and 95% interval",y=NULL,shape=NULL) + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter13/ci_growth.pdf",pci,width=7.1,height=5.1)

message("Chapter 13 robust-inference benchmark reproduced successfully.")
