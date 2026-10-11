# Chapter 11 - Choosing Among Pooled OLS, Fixed Effects, and Random Effects
# Run from project root: source("R/chapter11.R")

required <- c("readr", "dplyr", "tidyr", "plm", "lmtest", "sandwich", "ggplot2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))
for (d in c("tables/chapter11", "results/chapter11", "figures/chapter11")) dir.create(d, recursive=TRUE, showWarnings=FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types=FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::mutate(linvest=log(invest), lvalue=log(value), lcapital=log(capital))
stopifnot(nrow(dat)==200L, dplyr::n_distinct(dat$firm)==10L, dplyr::n_distinct(dat$year)==20L,
          !anyDuplicated(dat[c("firm","year")]), !anyNA(dat[c("invest","value","capital")]))
pdata <- plm::pdata.frame(dat, index=c("firm","year"), drop.index=FALSE)
stopifnot(plm::is.pbalanced(pdata))

# Comparable one-way models ---------------------------------------------------
pool <- plm::plm(linvest ~ lvalue + lcapital, data=pdata, model="pooling")
fe <- plm::plm(linvest ~ lvalue + lcapital, data=pdata, model="within", effect="individual")
re <- plm::plm(linvest ~ lvalue + lcapital, data=pdata, model="random", effect="individual", random.method="swar")
stopifnot(nobs(pool)==200L, nobs(fe)==200L, nobs(re)==200L)

# Tests -----------------------------------------------------------------------
fe_test <- plm::pFtest(fe, pool)
lm_test <- plm::plmtest(pool, effect="individual", type="bp")
hausman <- plm::phtest(fe, re)

stopifnot(abs(unname(fe_test$statistic) - 52.284645443) < 1e-6)
stopifnot(abs(unname(lm_test$statistic) - 754.636423561) < 1e-5)
stopifnot(abs(unname(hausman$statistic) - 7.715151276) < 1e-5)

# Manual Hausman reconstruction -----------------------------------------------
# Use equivalent LSDV/manual Swamy-Arora objects so the covariance difference is
# completely inspectable and tied to the published benchmark.
firm_lsdv <- stats::lm(linvest ~ lvalue + lcapital + factor(firm), data=dat)
# Within SSE and Swamy-Arora variance components.
wdat <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(w_y=linvest-mean(linvest), w_v=lvalue-mean(lvalue), w_c=lcapital-mean(lcapital)) |>
  dplyr::ungroup()
within_lm <- stats::lm(w_y ~ 0 + w_v + w_c, data=wdat)
firm_means <- dat |>
  dplyr::group_by(firm) |>
  dplyr::summarise(linvest=mean(linvest), lvalue=mean(lvalue), lcapital=mean(lcapital), .groups="drop")
between_lm <- stats::lm(linvest ~ lvalue + lcapital, data=firm_means)
N <- 10L; Tn <- 20L; K <- 2L
sigma_e2 <- sum(residuals(within_lm)^2) / (N*Tn - N - K)
sigma_b2 <- sum(residuals(between_lm)^2) / (N-K-1L)
sigma_a2 <- sigma_b2 - sigma_e2/Tn
theta <- 1 - sqrt(sigma_e2/(sigma_e2 + Tn*sigma_a2))
qd <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(qy=linvest-theta*mean(linvest), qv=lvalue-theta*mean(lvalue), qc=lcapital-theta*mean(lcapital)) |>
  dplyr::ungroup() |>
  dplyr::mutate(qconst=1-theta)
re_manual <- stats::lm(qy ~ 0 + qconst + qv + qc, data=qd)

b_fe <- coef(firm_lsdv)[c("lvalue","lcapital")]
b_re <- coef(re_manual)[c("qv","qc")]
V_fe <- vcov(firm_lsdv)[c("lvalue","lcapital"),c("lvalue","lcapital")]
V_re <- vcov(re_manual)[c("qv","qc"),c("qv","qc")]
q <- unname(b_fe - b_re)
Vdiff <- V_fe - V_re
H_manual <- as.numeric(t(q) %*% solve(Vdiff, q))
p_manual <- stats::pchisq(H_manual, df=2, lower.tail=FALSE)
stopifnot(max(abs(q - c(-0.070606013, 0.000402559))) < 1e-7)
stopifnot(max(abs(Vdiff - matrix(c(0.00209334735,-0.000215077491,-0.000215077491,0.000030899613),2,2))) < 1e-9)
stopifnot(abs(H_manual - 7.715151276) < 1e-6)

# Two-way FE and period test --------------------------------------------------
firm_fe_lm <- stats::lm(linvest ~ lvalue + lcapital + factor(firm), data=dat)
twoway_lm <- stats::lm(linvest ~ lvalue + lcapital + factor(firm) + factor(year), data=dat)
ssr_firm <- deviance(firm_fe_lm); ssr_tw <- deviance(twoway_lm)
F_period_given_firm <- ((ssr_firm-ssr_tw)/19)/(ssr_tw/169)
p_period_given_firm <- stats::pf(F_period_given_firm,19,169,lower.tail=FALSE)
stopifnot(abs(F_period_given_firm - 7.535040288) < 1e-6)

# Mundlak / correlated effects ------------------------------------------------
dat <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(mean_lvalue=mean(lvalue), mean_lcapital=mean(lcapital)) |>
  dplyr::ungroup()
mundlak_lm <- stats::lm(linvest ~ lvalue + lcapital + mean_lvalue + mean_lcapital + factor(year), data=dat)
expected_m <- c(lvalue=0.328554135,lcapital=0.076795861,mean_lvalue=0.418458450,mean_lcapital=0.384909139)
stopifnot(max(abs(coef(mundlak_lm)[names(expected_m)] - expected_m)) < 1e-6)

# Explicit CR1 covariance benchmark.  One-way CR1 uses
# G/(G-1) * (n-1)/(n-k); two-way clustering adds the firm and period
# components and subtracts the firm-period intersection component.
vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder=FALSE)
  bread <- solve(crossprod(X))
  correction <- (G/(G-1)) * ((n-1)/(n-k))
  correction * bread %*% crossprod(S) %*% bread
}
vcov_2way_cr1 <- function(model, c1, c2) {
  vcov_cr1(model,c1) + vcov_cr1(model,c2) -
    vcov_cr1(model,interaction(c1,c2,drop=TRUE))
}
V_mundlak <- vcov_2way_cr1(mundlak_lm, dat$firm, dat$year)
# Package implementation retained as a cross-check.  Do not silently replace
# the published benchmark if future package defaults change.
V_mundlak_pkg <- sandwich::vcovCL(mundlak_lm, cluster=dat[c("firm","year")], type="HC1", cadjust=TRUE)

joint_wald <- function(model,V,terms) {
  b <- coef(model)[terms]
  Vsub <- V[terms,terms,drop=FALSE]
  stat <- as.numeric(t(b) %*% solve(Vsub,b))
  data.frame(statistic=stat, df=length(terms), p.value=stats::pchisq(stat,length(terms),lower.tail=FALSE))
}
wald_means <- joint_wald(mundlak_lm,V_mundlak,c("mean_lvalue","mean_lcapital"))
stopifnot(abs(wald_means$statistic - 32.202709311) < 1e-5)

# Optional robust auxiliary Hausman sensitivity -------------------------------
hausman_aux_cluster <- plm::phtest(
  linvest ~ lvalue + lcapital, data=pdata,
  model=c("within","random"), effect="individual", method="aux",
  vcov=function(x) plm::vcovHC(x, method="arellano", type="HC1", cluster="group")
)

# First-log-difference effect checks ------------------------------------------
short <- dat |>
  dplyr::group_by(firm) |>
  dplyr::mutate(dlinvest=linvest-dplyr::lag(linvest), dlvalue=lvalue-dplyr::lag(lvalue), dlcapital=lcapital-dplyr::lag(lcapital)) |>
  dplyr::ungroup() |>
  dplyr::filter(stats::complete.cases(dlinvest,dlvalue,dlcapital))
short_pool <- stats::lm(dlinvest ~ dlvalue + dlcapital, data=short)
short_firm <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(firm), data=short)
short_time <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data=short)
F_fd_firm <- ((deviance(short_pool)-deviance(short_firm))/9)/(deviance(short_firm)/178)
F_fd_time <- ((deviance(short_pool)-deviance(short_time))/18)/(deviance(short_time)/169)
stopifnot(abs(F_fd_firm-0.194074151) < 1e-6, abs(F_fd_time-4.844946975) < 1e-6)

# Export ----------------------------------------------------------------------
utils::write.csv(data.frame(test=c("Pooled vs FE F","Pooled vs RE BP LM","FE vs RE Hausman","Period effects | firm FE","Mundlak means joint Wald","FD additional firm effects","FD period effects"),
  statistic=c(unname(fe_test$statistic),unname(lm_test$statistic),unname(hausman$statistic),F_period_given_firm,wald_means$statistic,F_fd_firm,F_fd_time),
  df1=c(9,1,2,19,2,9,18), df2=c(188,NA,NA,169,NA,178,169),
  p.value=c(fe_test$p.value,lm_test$p.value,hausman$p.value,p_period_given_firm,wald_means$p.value,stats::pf(F_fd_firm,9,178,lower.tail=FALSE),stats::pf(F_fd_time,18,169,lower.tail=FALSE))),
  "tables/chapter11/model_selection_tests.csv", row.names=FALSE)
utils::write.csv(data.frame(term=c("lvalue","lcapital"), FE=unname(b_fe), RE=unname(b_re), difference=q), "tables/chapter11/hausman_coefficients.csv", row.names=FALSE)
utils::write.csv(as.data.frame(Vdiff), "tables/chapter11/hausman_covariance_difference.csv")
utils::write.csv(data.frame(term=names(expected_m), estimate=coef(mundlak_lm)[names(expected_m)], std.error=sqrt(diag(V_mundlak))[names(expected_m)]), "tables/chapter11/mundlak_coefficients.csv", row.names=FALSE)
writeLines(capture.output(print(hausman_aux_cluster)), "results/chapter11/robust_auxiliary_hausman.txt")
writeLines(capture.output(sessionInfo()), "results/chapter11/sessionInfo.txt")

# Figures ---------------------------------------------------------------------
# Selection ladder
steps <- data.frame(x=1:3,y=1,label=c("Pooled vs FE\nAre firm intercepts needed?","Pooled vs RE\nIs variance component nonzero?","FE vs RE / CRE\nIs orthogonality credible?"))
p_sel <- ggplot2::ggplot(steps,ggplot2::aes(x,y,label=label)) + ggplot2::geom_label(size=3.2) +
  ggplot2::annotate("segment",x=1.18,xend=1.82,y=1,yend=1,arrow=grid::arrow(length=grid::unit(.1,"in"))) +
  ggplot2::annotate("segment",x=2.18,xend=2.82,y=1,yend=1,arrow=grid::arrow(length=grid::unit(.1,"in"))) +
  ggplot2::coord_cartesian(xlim=c(.6,3.4),ylim=c(.7,1.3)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter11/selection_ladder.pdf",p_sel,width=7.2,height=2.4)

coef_plot <- data.frame(estimator=rep(c("Pooled","RE","FE"),each=2), regressor=rep(c("log(value)","log(capital)"),3),
  estimate=c(coef(pool)["lvalue"],coef(pool)["lcapital"],coef(re)["lvalue"],coef(re)["lcapital"],coef(fe)["lvalue"],coef(fe)["lcapital"]))
p_coef <- ggplot2::ggplot(coef_plot,ggplot2::aes(estimator,estimate,group=regressor,shape=regressor)) + ggplot2::geom_point(size=2.7) + ggplot2::geom_line(ggplot2::aes(linetype=regressor)) + ggplot2::labs(x=NULL,y="Slope estimate",shape=NULL,linetype=NULL) + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter11/coefficient_selection.pdf",p_coef,width=6.8,height=3.7)

hausdf <- data.frame(term=c("log(value)","log(capital)"),difference=q,se=sqrt(diag(Vdiff)))
p_hd <- ggplot2::ggplot(hausdf,ggplot2::aes(term,difference)) + ggplot2::geom_hline(yintercept=0,linewidth=.35) + ggplot2::geom_errorbar(ggplot2::aes(ymin=difference-1.96*se,ymax=difference+1.96*se),width=.15) + ggplot2::geom_point(size=2.4) + ggplot2::coord_flip() + ggplot2::labs(x=NULL,y="FE - RE coefficient difference") + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter11/hausman_differences.pdf",p_hd,width=6.5,height=3.2)

mplot <- data.frame(term=c("mean log(value)","mean log(capital)"),estimate=coef(mundlak_lm)[c("mean_lvalue","mean_lcapital")],se=sqrt(diag(V_mundlak))[c("mean_lvalue","mean_lcapital")])
p_m <- ggplot2::ggplot(mplot,ggplot2::aes(term,estimate)) + ggplot2::geom_hline(yintercept=0,linewidth=.35) + ggplot2::geom_errorbar(ggplot2::aes(ymin=estimate-1.96*se,ymax=estimate+1.96*se),width=.15) + ggplot2::geom_point(size=2.4) + ggplot2::coord_flip() + ggplot2::labs(x=NULL,y="Mundlak firm-mean coefficient") + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter11/mundlak_means.pdf",p_m,width=6.5,height=3.2)

map <- data.frame(spec=c("Logged levels","First log differences"),result=c("Firm effects required; period effects required; RE orthogonality rejected","Additional firm effects redundant; period effects required"))
p_map <- ggplot2::ggplot(map,ggplot2::aes(x=1,y=spec,label=result)) + ggplot2::geom_label(size=3.1) + ggplot2::coord_cartesian(xlim=c(.8,1.2)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter11/specification_map.pdf",p_map,width=7.2,height=3.0)

message("Chapter 11 model-selection benchmarks reproduced successfully.")
