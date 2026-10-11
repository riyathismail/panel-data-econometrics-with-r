# Chapter 18 - Panel Forecasting, Prediction, and Forecast Evaluation
# Run from the RStudio Project root: source("R/chapter18.R")
required <- c("readr", "dplyr", "tidyr", "ggplot2", "plm")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))
for (d in c("tables/chapter18", "results/chapter18", "figures/chapter18")) dir.create(d, recursive=TRUE, showWarnings=FALSE)

dat <- readr::read_csv("data/Grunfeld_PanelData_2006_2025.csv", show_col_types=FALSE) |>
  dplyr::arrange(firm, year) |>
  dplyr::group_by(firm) |>
  dplyr::mutate(
    linvest=log(invest), lvalue=log(value), lcapital=log(capital),
    ginvest=linvest-dplyr::lag(linvest),
    gvalue=lvalue-dplyr::lag(lvalue),
    gcapital=lcapital-dplyr::lag(lcapital),
    L_ginvest=dplyr::lag(ginvest), L_gvalue=dplyr::lag(gvalue), L_gcapital=dplyr::lag(gcapital),
    invest_lag=dplyr::lag(invest)
  ) |> dplyr::ungroup()
stopifnot(nrow(dat)==200L, dplyr::n_distinct(dat$firm)==10L, dplyr::n_distinct(dat$year)==20L,
          sum(!is.na(dat$ginvest))==190L, sum(!is.na(dat$L_ginvest))==180L)

rmse <- function(a,f) sqrt(mean((a-f)^2)); mae <- function(a,f) mean(abs(a-f))
theil_u1 <- function(a,f) rmse(a,f)/(sqrt(mean(a^2))+sqrt(mean(f^2)))
origins <- 2021:2025
all_fc <- list(); coef_rows <- list()
for (j in seq_along(origins)) {
  fy <- origins[j]
  train_c <- dplyr::filter(dat, year < fy, !is.na(ginvest))
  test <- dplyr::filter(dat, year == fy)
  fit_c <- stats::lm(ginvest ~ gvalue + gcapital, data=train_c)
  pred_c <- stats::predict(fit_c, newdata=test, interval="prediction", level=.95)
  smear <- mean(exp(stats::residuals(fit_c)))
  train_l <- dplyr::filter(dat, year < fy, !is.na(L_ginvest))
  fit_l <- stats::lm(ginvest ~ L_ginvest + L_gvalue + L_gcapital, data=train_l)
  pred_l <- stats::predict(fit_l, newdata=test)
  pooled_mean <- mean(train_c$ginvest)
  fm <- train_c |> dplyr::group_by(firm) |> dplyr::summarise(firm_mean=mean(ginvest), .groups="drop")
  test <- test |> dplyr::left_join(fm, by="firm") |> dplyr::mutate(
    zero=0, pooled=pooled_mean, conditional=pred_c[,"fit"], lagged=pred_l,
    pi_lwr=pred_c[,"lwr"], pi_upr=pred_c[,"upr"], smear=smear,
    inv_med=invest_lag*exp(conditional), inv_mean=inv_med*smear, inv_nochange=invest_lag)
  all_fc[[j]] <- test
  coef_rows[[j]] <- data.frame(year=fy,n_cond=nrow(train_c),n_lag=nrow(train_l),
    constant=coef(fit_c)[1],gvalue=coef(fit_c)[2],gcapital=coef(fit_c)[3],smear=smear)
}
fc <- dplyr::bind_rows(all_fc); coefs <- dplyr::bind_rows(coef_rows)
expected_coef <- data.frame(
  year=2021:2025,
  constant=c(.0489826316063,.0444976864036,.0568667042048,.0598968031379,.0608951916545),
  gvalue=c(.558015393293,.553681206908,.586031297627,.579324606262,.580214986216),
  gcapital=c(-.0688693465564,-.0666352022852,-.0755050400360,-.0766446023168,-.0757593843879))
stopifnot(max(abs(coefs$constant-expected_coef$constant))<1e-9,
          max(abs(coefs$gvalue-expected_coef$gvalue))<1e-9,
          max(abs(coefs$gcapital-expected_coef$gcapital))<1e-9,
          identical(coefs$n_cond, c(140L,150L,160L,170L,180L)),
          identical(coefs$n_lag, c(130L,140L,150L,160L,170L)))

rules <- c(zero="Zero growth", pooled="Pooled historical mean", firm_mean="Firm historical mean", conditional="Conditional contemporaneous", lagged="Lagged-information ex ante")
acc <- do.call(rbind,lapply(names(rules),function(v){a<-fc$ginvest; f<-fc[[v]]; data.frame(rule=rules[[v]],RMSE=rmse(a,f),MAE=mae(a,f),mean_error=mean(a-f),Theil_U1=theil_u1(a,f))}))
expected_rmse <- c(.226443983208,.208732514892,.208766797448,.175860672082,.204945253341)
stopifnot(max(abs(acc$RMSE-expected_rmse))<1e-9)

period_acc <- do.call(rbind,lapply(origins,function(fy){g<-fc[fc$year==fy,]; data.frame(year=fy,zero=rmse(g$ginvest,g$zero),conditional=rmse(g$ginvest,g$conditional),lagged=rmse(g$ginvest,g$lagged))}))
expected_cond <- c(.172424,.227511,.112625,.092813,.227694)
stopifnot(max(abs(period_acc$conditional-expected_cond))<1e-6)

corr <- cor(fc$ginvest,fc$conditional)
stopifnot(abs(corr-.482675393994)<1e-9)
# Theil decomposition
y<-fc$ginvest; f<-fc$conditional; mse<-mean((y-f)^2)
theil_decomp <- data.frame(component=c("Bias","Variance","Covariance"), proportion=c(
  (mean(y)-mean(f))^2/mse,
  (sd(y)*sqrt((length(y)-1)/length(y)) - sd(f)*sqrt((length(f)-1)/length(f)))^2/mse,
  2*(sd(y)*sqrt((length(y)-1)/length(y)))*(sd(f)*sqrt((length(f)-1)/length(f)))*(1-cor(y,f))/mse))
stopifnot(abs(sum(theil_decomp$proportion)-1)<1e-10)

level_metrics <- function(f){e<-fc$invest-f; c(RMSE=sqrt(mean(e^2)),MAE=mean(abs(e)),MAPE=100*mean(abs(e/fc$invest)))}
level_acc <- rbind(`Conditional median`=level_metrics(fc$inv_med), `Smearing-corrected mean`=level_metrics(fc$inv_mean), `No-change level`=level_metrics(fc$inv_nochange))
stopifnot(abs(level_acc[1,"RMSE"]-60.29561320)<1e-6, abs(level_acc[2,"RMSE"]-56.14250926)<1e-6, abs(level_acc[3,"RMSE"]-80.16596623)<1e-6)
coverage <- mean(fc$ginvest>=fc$pi_lwr & fc$ginvest<=fc$pi_upr); mean_width <- mean(fc$pi_upr-fc$pi_lwr)
stopifnot(coverage==1, abs(mean_width-.961905035029)<1e-9)

readr::write_csv(coefs,"tables/chapter18/rolling_coefficients.csv")
readr::write_csv(acc,"tables/chapter18/growth_accuracy.csv")
readr::write_csv(period_acc,"tables/chapter18/period_rmse.csv")
readr::write_csv(as.data.frame(level_acc) |> tibble::rownames_to_column("forecast"),"tables/chapter18/level_accuracy.csv")
readr::write_csv(theil_decomp,"tables/chapter18/theil_decomposition.csv")
readr::write_csv(fc,"results/chapter18/rolling_forecasts.csv")
writeLines(capture.output(sessionInfo()),"results/chapter18/sessionInfo.txt")

# Publication figures
mean_path <- fc |> dplyr::group_by(year) |> dplyr::summarise(actual=mean(ginvest),conditional=mean(conditional),lagged=mean(lagged),.groups="drop") |> tidyr::pivot_longer(-year,names_to="series",values_to="growth")
p1<-ggplot2::ggplot(mean_path,ggplot2::aes(year,growth,linetype=series,shape=series))+ggplot2::geom_line()+ggplot2::geom_point()+ggplot2::labs(x="Teaching-period label",y="Mean investment log growth",linetype=NULL,shape=NULL)+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter18/mean_growth_forecasts.pdf",p1,width=7,height=4)
period_long<-period_acc |> tidyr::pivot_longer(-year,names_to="rule",values_to="RMSE")
p2<-ggplot2::ggplot(period_long,ggplot2::aes(year,RMSE,linetype=rule,shape=rule))+ggplot2::geom_line()+ggplot2::geom_point()+ggplot2::labs(x="Teaching-period label",linetype=NULL,shape=NULL)+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter18/rolling_rmse.pdf",p2,width=7,height=4)
p3<-ggplot2::ggplot(fc,ggplot2::aes(conditional,ginvest))+ggplot2::geom_point()+ggplot2::geom_abline(slope=1,intercept=0,linetype=2)+ggplot2::labs(x="Conditional forecast",y="Actual investment log growth")+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter18/forecast_scatter.pdf",p3,width=5.5,height=5)

# Forecast design figure
design <- data.frame(
  x=c(1,2.6,4.2,2.6,4.2), y=c(2.2,2.2,2.2,.8,.8),
  label=c("Estimate through t-1","Freeze information set","Forecast all 10 firms at t","Reveal actual outcomes","Expand origin and repeat")
)
p0 <- ggplot2::ggplot(design, ggplot2::aes(x,y,label=label)) +
  ggplot2::geom_label(size=3.1) +
  ggplot2::annotate("segment",x=1.45,xend=2.1,y=2.2,yend=2.2,arrow=grid::arrow(length=grid::unit(.1,"in"))) +
  ggplot2::annotate("segment",x=3.05,xend=3.7,y=2.2,yend=2.2,arrow=grid::arrow(length=grid::unit(.1,"in"))) +
  ggplot2::annotate("segment",x=4.2,xend=2.75,y=1.9,yend=1.05,arrow=grid::arrow(length=grid::unit(.1,"in"))) +
  ggplot2::annotate("segment",x=3.05,xend=3.7,y=.8,yend=.8,arrow=grid::arrow(length=grid::unit(.1,"in"))) +
  ggplot2::coord_cartesian(xlim=c(.4,4.8),ylim=c(.3,2.7)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter18/forecast_design.pdf",p0,width=7,height=3.5)

# Aggregate RMSE/MAE comparison
metric_long <- acc |> dplyr::select(rule,RMSE,MAE) |> tidyr::pivot_longer(-rule,names_to="metric",values_to="loss")
pm <- ggplot2::ggplot(metric_long,ggplot2::aes(rule,loss,fill=metric)) + ggplot2::geom_col(position="dodge") +
  ggplot2::labs(x=NULL,y="Loss",fill=NULL) + ggplot2::theme_minimal(base_size=10) +
  ggplot2::theme(axis.text.x=ggplot2::element_text(angle=25,hjust=1))
ggplot2::ggsave("figures/chapter18/forecast_metrics.pdf",pm,width=7,height=4)

message("Chapter 18 benchmark reproduced successfully.")
