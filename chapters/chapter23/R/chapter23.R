# Attach survival for the coxph call evaluated by clogit.
library(survival)
# Chapter 23 - Limited Dependent Variables and Nonlinear Panel Models
# Run from the RStudio Project root: source("R/chapter23.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "fixest", "sandwich", "marginaleffects", "survival", "lme4")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))
for (d in c("tables/chapter23", "results/chapter23", "figures/chapter23")) dir.create(d, recursive = TRUE, showWarnings = FALSE)

raw <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types = FALSE) |>
  dplyr::arrange(firm, year)
stopifnot(nrow(raw) == 200L, dplyr::n_distinct(raw$firm) == 10L, dplyr::n_distinct(raw$year) == 20L)
stopifnot(!anyDuplicated(raw[c("firm", "year")]), !anyNA(raw[c("invest", "value", "capital")]))

dat <- raw |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest = log(invest), lvalue = log(value), lcapital = log(capital),
    ginvest = linvest - dplyr::lag(linvest),
    gvalue = lvalue - dplyr::lag(lvalue),
    gcapital = lcapital - dplyr::lag(lcapital)
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(stats::complete.cases(ginvest, gvalue, gcapital)) |>
  dplyr::mutate(
    original_year = year - 71L,
    pos_invest_growth = as.integer(ginvest > 0),
    trend = year - 2007L
  )
stopifnot(nrow(dat) == 190L, sum(dat$pos_invest_growth) == 117L, abs(mean(dat$pos_invest_growth) - 0.6157894736842106) < 1e-12)
stopifnot(all(tapply(dat$pos_invest_growth, dat$firm, min) == 0L), all(tapply(dat$pos_invest_growth, dat$firm, max) == 1L))
stopifnot(mean(dat$pos_invest_growth[dat$year == 2022]) == 1)
readr::write_csv(dat, "data/Grunfeld_Binary_Teaching.csv")

# Explicit covariance helpers -------------------------------------------------
vcov_cr1_lm <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X)); meat <- crossprod(S)
  (G/(G-1))*((n-1)/(n-k)) * bread %*% meat %*% bread
}
vcov_cr1_logit <- function(model, cluster) {
  X <- stats::model.matrix(model); y <- stats::model.response(stats::model.frame(model)); p <- stats::fitted(model)
  n <- nrow(X); k <- ncol(X); g <- factor(cluster); G <- nlevels(g)
  score <- X * as.numeric(y - p)
  S <- rowsum(score, g, reorder = FALSE)
  W <- as.numeric(p * (1-p)); bread <- solve(crossprod(X, X * W)); meat <- crossprod(S)
  (G/(G-1))*((n-1)/(n-k)) * bread %*% meat %*% bread
}
vcov_2way <- function(one_fun, model, c1, c2) {
  one_fun(model,c1) + one_fun(model,c2) - one_fun(model, interaction(c1,c2,drop=TRUE))
}

# LPM -------------------------------------------------------------------------
lpm <- stats::lm(pos_invest_growth ~ gvalue + gcapital + factor(firm) + factor(year), data = dat)
lpm_fx <- fixest::feols(pos_invest_growth ~ gvalue + gcapital | firm + year, data = dat)
stopifnot(max(abs(unname(coef(lpm)[c("gvalue","gcapital")]) - unname(coef(lpm_fx)))) < 1e-10)
stopifnot(abs(coef(lpm)["gvalue"] - 0.958795342) < 1e-9, abs(coef(lpm)["gcapital"] - (-0.098249288)) < 1e-9)
stopifnot(abs(min(fitted(lpm)) - (-0.3200782851)) < 1e-9, abs(max(fitted(lpm)) - 1.3843256804) < 1e-9)
stopifnot(sum(fitted(lpm) < 0 | fitted(lpm) > 1) == 19L)
Vl_firm <- vcov_cr1_lm(lpm, dat$firm); Vl_period <- vcov_cr1_lm(lpm, dat$year); Vl_2way <- vcov_2way(vcov_cr1_lm,lpm,dat$firm,dat$year)
idx_l <- match(c("gvalue","gcapital"), names(coef(lpm)))
stopifnot(max(abs(sqrt(diag(Vl_firm)[idx_l]) - c(0.317917447,0.088105518))) < 1e-7)
stopifnot(max(abs(sqrt(diag(Vl_period)[idx_l]) - c(0.170861482,0.112104655))) < 1e-7)
stopifnot(max(abs(sqrt(diag(Vl_2way)[idx_l]) - c(0.292930647,0.110654621))) < 1e-7)

# Unconditional FE logit/probit ----------------------------------------------
logit_fe <- stats::glm(pos_invest_growth ~ gvalue + gcapital + trend + factor(firm), family = stats::binomial("logit"), data = dat, control = stats::glm.control(epsilon=1e-12,maxit=100))
probit_fe <- stats::glm(pos_invest_growth ~ gvalue + gcapital + trend + factor(firm), family = stats::binomial("probit"), data = dat, control = stats::glm.control(epsilon=1e-12,maxit=100))
logit_fx <- fixest::feglm(pos_invest_growth ~ gvalue + gcapital + trend | firm, family = stats::binomial("logit"), data = dat)
stopifnot(max(abs(coef(logit_fe)[c("gvalue","gcapital","trend")] - c(gvalue=6.235810524,gcapital=-0.888360703,trend=0.031538283))) < 1e-7)
stopifnot(max(abs(unname(coef(logit_fx)) - unname(coef(logit_fe)[c("gvalue","gcapital","trend")]))) < 1e-7)
stopifnot(max(abs(coef(probit_fe)[c("gvalue","gcapital","trend")] - c(gvalue=3.715630862,gcapital=-0.526048253,trend=0.023000731))) < 1e-7)
stopifnot(abs(as.numeric(logLik(logit_fe)) - (-99.513001263)) < 1e-7)
logit_null <- stats::glm(pos_invest_growth ~ 1, family=stats::binomial("logit"), data=dat)
logit_restricted <- stats::glm(pos_invest_growth ~ trend + factor(firm), family=stats::binomial("logit"), data=dat)
stopifnot(abs(1 - as.numeric(logLik(logit_fe))/as.numeric(logLik(logit_null)) - 0.213688302) < 1e-7)
LR <- 2*(as.numeric(logLik(logit_fe)) - as.numeric(logLik(logit_restricted)))
stopifnot(abs(LR - 44.849422189) < 1e-7)

Vg_firm <- vcov_cr1_logit(logit_fe, dat$firm); Vg_period <- vcov_cr1_logit(logit_fe,dat$year); Vg_2way <- vcov_2way(vcov_cr1_logit,logit_fe,dat$firm,dat$year)
idx_g <- match(c("gvalue","gcapital","trend"), names(coef(logit_fe)))
stopifnot(max(abs(sqrt(diag(Vg_firm)[idx_g]) - c(1.456111337,0.443535499,0.026660951))) < 1e-7)
stopifnot(max(abs(sqrt(diag(Vg_period)[idx_g[1:2]]) - c(1.427449448,0.513778107))) < 1e-7)
stopifnot(max(abs(sqrt(diag(Vg_2way)[idx_g[1:2]]) - c(1.656720394,0.477264289))) < 1e-7)
# Substantive-block eigenvalues are reported without repairing the covariance.
write.csv(data.frame(eigenvalue=eigen(Vg_2way[idx_g[1:2],idx_g[1:2]],symmetric=TRUE)$values),
          "tables/chapter23/logit_two_way_substantive_eigenvalues.csv",row.names=FALSE)
# package cross-check
Vg_pkg <- sandwich::vcovCL(logit_fe, cluster = dat[c("firm","year")], type="HC1", cadjust=TRUE)
# Package GLM information is based on its iterative fitted weights; compare on
# the scale of the covariance rather than an absolute coefficient-unit cutoff.
covariance_relative_error <- max(abs(Vg_pkg[idx_g,idx_g]-Vg_2way[idx_g,idx_g])) /
  max(abs(Vg_2way[idx_g,idx_g]))
stopifnot(covariance_relative_error < 1e-6)
writeLines(sprintf("sandwich/manual relative covariance error: %.12g",covariance_relative_error),
           "results/chapter23/independent_covariance_check.txt")

# AMEs and finite change -------------------------------------------------------
phat <- stats::predict(logit_fe, type="response")
link_density <- phat*(1-phat)
ame_manual <- c(
  gvalue = mean(link_density * coef(logit_fe)["gvalue"]),
  gcapital = mean(link_density * coef(logit_fe)["gcapital"]),
  trend = mean(link_density * coef(logit_fe)["trend"])
)
stopifnot(max(abs(ame_manual - c(gvalue=1.094722339,gcapital=-0.155955397,trend=0.005536676))) < 1e-7)
ame_pkg <- marginaleffects::avg_slopes(logit_fe, variables=c("gvalue","gcapital","trend"))
new_value <- dat; new_value$gvalue <- new_value$gvalue + log(1.10)
exact_value_10 <- mean(predict(logit_fe,new_value,type="response") - phat)
stopifnot(abs(exact_value_10 - 0.097995928) < 1e-7)
stopifnot(abs(exp(coef(logit_fe)["gvalue"]*log(1.10)) - 1.811827895) < 1e-7)

# Probit AMEs
xbp <- stats::predict(probit_fe, type="link"); densp <- stats::dnorm(xbp)
pame <- c(gvalue=mean(densp*coef(probit_fe)["gvalue"]), gcapital=mean(densp*coef(probit_fe)["gcapital"]))
stopifnot(max(abs(pame - c(gvalue=1.093494189,gcapital=-0.154813739))) < 1e-7)
newp <- dat; newp$gvalue <- newp$gvalue + log(1.10)
stopifnot(abs(mean(predict(probit_fe,newp,type="response")-predict(probit_fe,type="response")) - 0.098447581) < 1e-7)

# Conditional fixed-effects logit --------------------------------------------
clogit_fe <- survival::clogit(pos_invest_growth ~ gvalue + gcapital + trend + survival::strata(firm), data=dat, method="exact")
cb <- coef(clogit_fe); cse <- sqrt(diag(vcov(clogit_fe)))
# Exact conditional likelihood implementations differ in the last displayed digits.
# Check economically negligible numerical agreement while keeping the SE checks.
stopifnot(max(abs(cb - c(gvalue=5.850297170,gcapital=-0.835535254,trend=0.029515925))) < 2e-5)
stopifnot(max(abs(cse - c(gvalue=1.128894910,gcapital=0.582749417,trend=0.032848435))) < 2e-6)
stopifnot(abs(exp(cb["gvalue"]*log(1.10)) - 1.746463481) < 2e-6)

# Prediction diagnostics ------------------------------------------------------
y <- dat$pos_invest_growth; cls <- as.integer(phat >= 0.5)
TN <- sum(y==0 & cls==0); FP <- sum(y==0 & cls==1); FN <- sum(y==1 & cls==0); TP <- sum(y==1 & cls==1)
stopifnot(c(TN,FP,FN,TP) == c(36L,37L,21L,96L))
accuracy <- mean(cls==y); sensitivity <- TP/(TP+FN); specificity <- TN/(TN+FP)
auc_rank <- function(y,p) { r <- rank(p,ties.method="average"); n1 <- sum(y==1); n0 <- sum(y==0); (sum(r[y==1])-n1*(n1+1)/2)/(n1*n0) }
auc <- auc_rank(y,phat); brier <- mean((y-phat)^2); logloss <- -mean(y*log(phat)+(1-y)*log(1-phat))
stopifnot(abs(accuracy-0.694736842) < 1e-9, abs(auc-0.801662569) < 1e-9, abs(brier-0.177447089) < 1e-9, abs(logloss-0.523752638) < 1e-9)
qbreaks <- stats::quantile(phat, probs=seq(0,1,.2), type=7); qbreaks <- unique(qbreaks)
dat$calibration_bin <- cut(phat, breaks=qbreaks, include.lowest=TRUE)
cal <- dat |> dplyr::group_by(calibration_bin) |> dplyr::summarise(n=dplyr::n(), mean_pred=mean(phat), event_rate=mean(pos_invest_growth), .groups="drop")

# Leave-one-firm-out -----------------------------------------------------------
loo <- dplyr::bind_rows(lapply(sort(unique(dat$firm)), function(f) {
  fit <- glm(pos_invest_growth ~ gvalue + gcapital + trend + factor(firm), family=binomial("logit"), data=dat[dat$firm != f,])
  data.frame(omitted_firm=f, gvalue=coef(fit)["gvalue"], gcapital=coef(fit)["gcapital"])
}))
stopifnot(abs(min(loo$gvalue)-5.369206723) < 1e-7, abs(max(loo$gvalue)-6.806538090) < 1e-7)
stopifnot(abs(min(loo$gcapital)-(-1.096466967)) < 1e-7, abs(max(loo$gcapital)-(-0.535680545)) < 1e-7)

# Random-effects and correlated RE templates (not benchmark-final models) -----
re_logit <- lme4::glmer(pos_invest_growth ~ gvalue + gcapital + trend + (1|firm), family=binomial("logit"), data=dat, nAGQ=9)
cre_dat <- dat |> dplyr::group_by(firm) |> dplyr::mutate(mean_gvalue=mean(gvalue), mean_gcapital=mean(gcapital)) |> dplyr::ungroup()
cre_logit <- lme4::glmer(pos_invest_growth ~ gvalue + gcapital + trend + mean_gvalue + mean_gcapital + (1|firm), family=binomial("logit"), data=cre_dat, nAGQ=9)

# Export ----------------------------------------------------------------------
readr::write_csv(dat, "results/chapter23/binary_case_data.csv")
readr::write_csv(cal, "tables/chapter23/calibration_quintiles.csv")
readr::write_csv(loo, "tables/chapter23/leave_one_firm_out.csv")
write.csv(data.frame(term=c("gvalue","gcapital"), lpm=coef(lpm)[c("gvalue","gcapital")], logit=coef(logit_fe)[c("gvalue","gcapital")], probit=coef(probit_fe)[c("gvalue","gcapital")], clogit=cb[c("gvalue","gcapital")]), "tables/chapter23/model_coefficients.csv", row.names=FALSE)
write.csv(data.frame(metric=c("accuracy","sensitivity","specificity","AUC","Brier","log_loss"), value=c(accuracy,sensitivity,specificity,auc,brier,logloss)), "tables/chapter23/prediction_metrics.csv", row.names=FALSE)
write.csv(data.frame(covariance=c("Firm","Period","Two-way"), gvalue_se=c(sqrt(diag(Vg_firm)[idx_g[1]]),sqrt(diag(Vg_period)[idx_g[1]]),sqrt(diag(Vg_2way)[idx_g[1]])), gcapital_se=c(sqrt(diag(Vg_firm)[idx_g[2]]),sqrt(diag(Vg_period)[idx_g[2]]),sqrt(diag(Vg_2way)[idx_g[2]]))), "tables/chapter23/logit_covariance_sensitivity.csv", row.names=FALSE)
writeLines(capture.output(sessionInfo()), "results/chapter23/sessionInfo.txt")

# Figures ---------------------------------------------------------------------
period_rates <- dat |> dplyr::group_by(year) |> dplyr::summarise(event_rate=mean(pos_invest_growth), .groups="drop")
p1 <- ggplot2::ggplot(period_rates, ggplot2::aes(year,event_rate)) + ggplot2::geom_line() + ggplot2::geom_point() + ggplot2::scale_y_continuous(limits=c(0,1)) + ggplot2::labs(x="Teaching-period label",y="Share with positive investment growth") + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter23/binary_period_rates.pdf",p1,width=7,height=4)

response_grid <- data.frame(gvalue=seq(stats::quantile(dat$gvalue,.02),stats::quantile(dat$gvalue,.98),length.out=200), gcapital=0, trend=mean(dat$trend), firm=1L)
response_grid$logit <- predict(logit_fe,response_grid,type="response"); response_grid$probit <- predict(probit_fe,response_grid,type="response")
resp_long <- tidyr::pivot_longer(response_grid,c(logit,probit),names_to="model",values_to="probability")
p2 <- ggplot2::ggplot(resp_long,ggplot2::aes(gvalue,probability,linetype=model)) + ggplot2::geom_line(linewidth=.8) + ggplot2::labs(x="Firm-market-value log growth",y="Predicted probability",linetype=NULL) + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter23/probability_response.pdf",p2,width=7,height=4.2)

ame_df <- data.frame(model=c("LPM","Logit AME","Probit AME"), value=c(coef(lpm)["gvalue"],ame_manual["gvalue"],pame["gvalue"]))
p3 <- ggplot2::ggplot(ame_df,ggplot2::aes(model,value)) + ggplot2::geom_col() + ggplot2::labs(x=NULL,y="Reported scale") + ggplot2::theme_minimal(base_size=10) + ggplot2::theme(axis.text.x=ggplot2::element_text(angle=20,hjust=1))
ggplot2::ggsave("figures/chapter23/model_ame_comparison.pdf",p3,width=7,height=4.2)

p4 <- ggplot2::ggplot(cal,ggplot2::aes(mean_pred,event_rate)) + ggplot2::geom_abline(slope=1,intercept=0,linetype=2) + ggplot2::geom_point(size=2.5) + ggplot2::geom_line() + ggplot2::coord_equal(xlim=c(0,1),ylim=c(0,1)) + ggplot2::labs(x="Mean predicted probability",y="Observed event rate") + ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter23/calibration_plot.pdf",p4,width=5.2,height=5.2)

message("Chapter 23 benchmark reproduced successfully.")
