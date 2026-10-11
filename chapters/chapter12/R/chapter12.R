# Chapter 12 - Panel Regression Diagnostics
# Run from the RStudio Project root: source("R/chapter12.R")

# Attach plm because pwartest evaluates a model call in the formula environment.
library(plm)

required <- c("readr", "dplyr", "tidyr", "ggplot2", "plm", "lmtest", "sandwich", "skedastic")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))

for (d in c("tables/chapter12", "results/chapter12", "figures/chapter12"))
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
stopifnot(nrow(dat) == 200L, dplyr::n_distinct(dat$firm) == 10L, dplyr::n_distinct(dat$year) == 20L,
          !anyDuplicated(dat[c("firm", "year")]), !anyNA(dat[c("invest", "value", "capital")]))

pdata <- plm::pdata.frame(dat, index = c("firm", "year"), drop.index = FALSE)
level_plm <- plm::plm(linvest ~ lvalue + lcapital, data = pdata, model = "within", effect = "twoways")
level_lsdv <- stats::lm(linvest ~ lvalue + lcapital + factor(firm) + factor(year), data = dat)
stopifnot(max(abs(unname(coef(level_plm)) - unname(coef(level_lsdv)[c("lvalue","lcapital")]))) < 1e-10)
stopifnot(max(abs(unname(coef(level_plm)) - c(0.32855413, 0.07679586))) < 1e-7)
stopifnot(abs(summary(level_lsdv)$r.squared - 0.978640279846) < 1e-10)

growth <- dat |>
  dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital))
growth_lm <- stats::lm(dlinvest ~ dlvalue + dlcapital + factor(year), data = growth)
p_growth <- plm::pdata.frame(growth, index = c("firm","year"), drop.index = FALSE)
growth_plm <- plm::plm(dlinvest ~ dlvalue + dlcapital, data = p_growth, model = "within", effect = "time")
stopifnot(max(abs(unname(coef(growth_plm)) - unname(coef(growth_lm)[c("dlvalue","dlcapital")]))) < 1e-10)
stopifnot(max(abs(unname(coef(growth_plm)) - c(0.49570942, -0.08569261))) < 1e-7)
stopifnot(abs(summary(growth_lm)$r.squared - 0.492530736506) < 1e-10, nrow(growth) == 190L)

# Helpers ---------------------------------------------------------------------
group_lr <- function(residual, group) {
  n <- length(residual); ss <- sum(residual^2)
  pieces <- split(residual, group)
  lr <- n * log(ss / n) - sum(vapply(pieces, function(e) length(e) * log(sum(e^2) / length(e)), numeric(1)))
  df <- length(pieces) - 1L
  c(statistic = lr, df = df, p.value = stats::pchisq(lr, df, lower.tail = FALSE))
}

vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X)); meat <- crossprod(S)
  (G/(G-1)) * ((n-1)/(n-k)) * bread %*% meat %*% bread
}
vcov_2way_cr1 <- function(model, c1, c2) {
  vcov_cr1(model,c1) + vcov_cr1(model,c2) - vcov_cr1(model, interaction(c1,c2,drop=TRUE))
}

ar_residual <- function(residual, firm, h0 = 0) {
  z <- data.frame(firm = firm, residual = residual) |>
    dplyr::group_by(firm) |>
    dplyr::mutate(lag_residual = dplyr::lag(residual)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(lag_residual))
  m <- stats::lm(residual ~ 0 + lag_residual, data = z)
  V <- vcov_cr1(m, z$firm)
  se <- sqrt(V[1,1]); b <- coef(m)[1]; t <- (b-h0)/se
  data.frame(estimate=b, std.error=se, null=h0, statistic=t, df=dplyr::n_distinct(z$firm)-1L,
             p.value=2*stats::pt(abs(t),df=dplyr::n_distinct(z$firm)-1L,lower.tail=FALSE), n=nrow(z))
}

cd_summary <- function(residual, firm, year) {
  z <- data.frame(residual=residual, firm=firm, year=year)
  wide <- stats::xtabs(residual ~ year + firm, data=z)
  R <- stats::cor(wide); vals <- R[upper.tri(R)]
  N <- ncol(R); Tn <- nrow(wide)
  lm <- Tn * sum(vals^2)
  scaled <- (lm - N*(N-1)/2) / sqrt(N*(N-1))
  cd <- sqrt(2*Tn/(N*(N-1))) * sum(vals)
  data.frame(mean.rho=mean(vals), mean.abs.rho=mean(abs(vals)), LM=lm, scaled.LM=scaled, CD=cd,
             CD.p.value=2*stats::pnorm(abs(cd),lower.tail=FALSE))
}

jb_moments <- function(e) {
  n <- length(e); z <- e - mean(e); m2 <- mean(z^2)
  skew <- mean(z^3)/m2^(3/2); kurt <- mean(z^4)/m2^2
  jb <- n/6*(skew^2+(kurt-3)^2/4)
  data.frame(sd=stats::sd(e),skewness=skew,kurtosis=kurt,JB=jb,p.value=stats::pchisq(jb,2,lower.tail=FALSE))
}

reset_cluster <- function(model, c1, c2) {
  X0 <- stats::model.matrix(model)
  y <- stats::model.response(stats::model.frame(model))
  fit <- stats::fitted(model)
  X <- cbind(X0, fit2 = fit^2, fit3 = fit^3)
  beta <- solve(crossprod(X), crossprod(X, y))
  e <- as.numeric(y - X %*% beta)
  # CR1 matrix helper on an explicit design matrix.
  vcov_cr1_matrix <- function(X, e, cluster) {
    n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
    S <- rowsum(X * e, g, reorder = FALSE)
    bread <- solve(crossprod(X)); meat <- crossprod(S)
    (G/(G-1)) * ((n-1)/(n-k)) * bread %*% meat %*% bread
  }
  V <- vcov_cr1_matrix(X,e,c1) + vcov_cr1_matrix(X,e,c2) -
       vcov_cr1_matrix(X,e,interaction(c1,c2,drop=TRUE))
  ix <- match(c("fit2","fit3"),colnames(X)); b <- beta[ix]; VV <- V[ix,ix]
  W <- as.numeric(t(b) %*% solve(VV,b))
  data.frame(chi.square=W,df=2L,p.value=stats::pchisq(W,2,lower.tail=FALSE))
}

# Heteroskedasticity ----------------------------------------------------------
hetero <- dplyr::bind_rows(
  cbind(model="Level two-way FE",group="Firm",as.data.frame(as.list(group_lr(residuals(level_lsdv),dat$firm)))),
  cbind(model="Level two-way FE",group="Teaching period",as.data.frame(as.list(group_lr(residuals(level_lsdv),dat$year)))),
  cbind(model="Growth + period FE",group="Firm",as.data.frame(as.list(group_lr(residuals(growth_lm),growth$firm)))),
  cbind(model="Growth + period FE",group="Teaching period",as.data.frame(as.list(group_lr(residuals(growth_lm),growth$year))))
)
stopifnot(max(abs(hetero$statistic-c(28.88457359,36.07797935,17.79522974,39.08547524))) < 1e-7)
BP_level <- lmtest::bptest(level_lsdv); BP_growth <- lmtest::bptest(growth_lm)
# White tests are run on the effect-residualized substantive designs to avoid
# treating dummy squares as distinct economic variance regressors.
tw_y <- dat$linvest-ave(dat$linvest,dat$firm,FUN=mean)-ave(dat$linvest,dat$year,FUN=mean)+mean(dat$linvest)
tw_x1 <- dat$lvalue-ave(dat$lvalue,dat$firm,FUN=mean)-ave(dat$lvalue,dat$year,FUN=mean)+mean(dat$lvalue)
tw_x2 <- dat$lcapital-ave(dat$lcapital,dat$firm,FUN=mean)-ave(dat$lcapital,dat$year,FUN=mean)+mean(dat$lcapital)
white_level_model <- stats::lm(tw_y ~ tw_x1 + tw_x2)
pw_y <- growth$dlinvest-ave(growth$dlinvest,growth$year,FUN=mean)
pw_x1 <- growth$dlvalue-ave(growth$dlvalue,growth$year,FUN=mean)
pw_x2 <- growth$dlcapital-ave(growth$dlcapital,growth$year,FUN=mean)
white_growth_model <- stats::lm(pw_y ~ pw_x1 + pw_x2)
White_level <- skedastic::white(white_level_model); White_growth <- skedastic::white(white_growth_model)

# Serial correlation ----------------------------------------------------------
serial_level <- ar_residual(residuals(level_lsdv),dat$firm,h0=0)
serial_growth_zero <- ar_residual(residuals(growth_lm),growth$firm,h0=0)
serial_growth_fe <- ar_residual(residuals(growth_lm),growth$firm,h0=-0.5)
stopifnot(abs(serial_level$estimate-0.5763595850)<1e-9, abs(serial_level$std.error-0.0506840245)<1e-9)
stopifnot(abs(serial_growth_zero$estimate-(-0.0689790101))<1e-9, abs(serial_growth_zero$p.value-0.4706295335)<1e-9)
stopifnot(abs(serial_growth_fe$statistic-4.705810858)<1e-8, abs(serial_growth_fe$p.value-0.0011110431)<1e-9)

# Native plm tests retained as output checks when R is executed.
fd_base <- plm::plm(linvest ~ lvalue + lcapital, data=pdata, model="fd")
pwfd_fe <- plm::pwfdtest(fd_base,h0="fe",type="HC1")
pwfd_fd <- plm::pwfdtest(fd_base,h0="fd",type="HC1")
pwar_level <- plm::pwartest(linvest ~ lvalue + lcapital + factor(year), data=pdata,type="HC1")
pbg_level <- plm::pbgtest(level_plm,order=1)

# Cross-sectional dependence --------------------------------------------------
firm_only <- stats::lm(linvest ~ lvalue + lcapital + factor(firm),data=dat)
growth_no_period <- stats::lm(dlinvest ~ dlvalue + dlcapital,data=growth)
cd <- dplyr::bind_rows(
  cbind(model="Level firm FE only",cd_summary(residuals(firm_only),dat$firm,dat$year)),
  cbind(model="Level two-way FE",cd_summary(residuals(level_lsdv),dat$firm,dat$year)),
  cbind(model="Growth no period FE",cd_summary(residuals(growth_no_period),growth$firm,growth$year)),
  cbind(model="Growth + period FE",cd_summary(residuals(growth_lm),growth$firm,growth$year))
)
# Ordinary CD/LM reference distributions are not calibrated after complete period effects.
cd$CD.p.value[c(2,4)] <- NA_real_
cd$reference <- c("ordinary independent-panel reference", "descriptive after period FE", "ordinary independent-panel reference", "descriptive after period FE")
stopifnot(max(abs(cd$CD-c(7.11359454,-3.15072354,7.79464294,-3.08684298)))<1e-7)
pcd_level <- list(cd=plm::pcdtest(level_plm,test="cd"),sclm=plm::pcdtest(level_plm,test="sclm"),lm=plm::pcdtest(level_plm,test="lm"))
pcd_growth <- list(cd=plm::pcdtest(growth_plm,test="cd"),sclm=plm::pcdtest(growth_plm,test="sclm"),lm=plm::pcdtest(growth_plm,test="lm"))

# Estimator-relevant collinearity --------------------------------------------
tw_lvalue <- dat$lvalue-ave(dat$lvalue,dat$firm,FUN=mean)-ave(dat$lvalue,dat$year,FUN=mean)+mean(dat$lvalue)
tw_lcapital <- dat$lcapital-ave(dat$lcapital,dat$firm,FUN=mean)-ave(dat$lcapital,dat$year,FUN=mean)+mean(dat$lcapital)
rho_level <- cor(tw_lvalue,tw_lcapital); vif_level <- 1/(1-rho_level^2)
pw_dlvalue <- growth$dlvalue-ave(growth$dlvalue,growth$year,FUN=mean)
pw_dlcapital <- growth$dlcapital-ave(growth$dlcapital,growth$year,FUN=mean)
rho_growth <- cor(pw_dlvalue,pw_dlcapital); vif_growth <- 1/(1-rho_growth^2)
stopifnot(abs(rho_level-0.1866835520)<1e-10,abs(vif_level-1.0361091806)<1e-10)
stopifnot(abs(rho_growth-(-0.06202950935))<1e-10,abs(vif_growth-1.0038625217)<1e-10)

# Normality -------------------------------------------------------------------
normality <- dplyr::bind_rows(cbind(model="Level two-way FE",jb_moments(residuals(level_lsdv))),cbind(model="Growth + period FE",jb_moments(residuals(growth_lm))))
stopifnot(abs(normality$JB[1]-4.0189338321)<1e-9,abs(normality$JB[2]-5.1048285185)<1e-9)

# RESET -----------------------------------------------------------------------
reset_level <- lmtest::resettest(level_lsdv,power=2:3,type="fitted")
reset_growth <- lmtest::resettest(growth_lm,power=2:3,type="fitted")
reset_level_cluster <- reset_cluster(level_lsdv,dat$firm,dat$year)
reset_growth_cluster <- reset_cluster(growth_lm,growth$firm,growth$year)
stopifnot(abs(unname(reset_level$statistic)-5.14587133)<1e-7,abs(reset_level$p.value-0.006781642)<1e-8)
stopifnot(abs(unname(reset_growth$statistic)-0.48766561)<1e-7,abs(reset_growth$p.value-0.614929854)<1e-8)
stopifnot(abs(reset_level_cluster$chi.square-9.694844397)<1e-7,abs(reset_growth_cluster$chi.square-0.697045250)<1e-7)

# Influence -------------------------------------------------------------------
make_influence <- function(model, meta) {
  data.frame(meta,cook=stats::cooks.distance(model),rstudent=stats::rstudent(model),dffits=stats::dffits(model),covratio=stats::covratio(model),hat=stats::hatvalues(model))
}
inf_level <- make_influence(level_lsdv,dat[c("firm","year")])
inf_growth <- make_influence(growth_lm,growth[c("firm","year")])
stopifnot(sum(inf_level$cook>4/nrow(dat))==14L,sum(inf_growth$cook>4/nrow(growth))==11L)
stopifnot(abs(max(inf_level$cook)-0.07019045736)<1e-10,abs(max(inf_growth$cook)-0.1043938664)<1e-10)

# Exports ---------------------------------------------------------------------
write.csv(hetero,"tables/chapter12/groupwise_variance_lr.csv",row.names=FALSE)
write.csv(cd,"tables/chapter12/cross_section_dependence.csv",row.names=FALSE)
write.csv(normality,"tables/chapter12/residual_normality.csv",row.names=FALSE)
write.csv(data.frame(model=c("Level","Growth"),rho=c(rho_level,rho_growth),VIF=c(vif_level,vif_growth)),"tables/chapter12/estimator_relevant_vif.csv",row.names=FALSE)
write.csv(inf_level[order(-inf_level$cook),],"results/chapter12/influence_level.csv",row.names=FALSE)
write.csv(inf_growth[order(-inf_growth$cook),],"results/chapter12/influence_growth.csv",row.names=FALSE)
writeLines(capture.output(sessionInfo()),"results/chapter12/sessionInfo.txt")

# Figures ---------------------------------------------------------------------
# Diagnostic workflow
workflow <- data.frame(x=c(1,2,3,4,5,6),y=1,label=c("Define target equation","Residual variance","Within-firm serial correlation","Cross-section dependence","Form / collinearity / influence","Choose remedy in Chapter 13"))
p0 <- ggplot2::ggplot(workflow,ggplot2::aes(x,y,label=label)) + ggplot2::geom_label(size=3) +
  ggplot2::geom_segment(data=data.frame(x=1:5,xend=2:6,y=1,yend=1),ggplot2::aes(x=x,xend=xend,y=y,yend=yend),inherit.aes=FALSE,arrow=grid::arrow(length=grid::unit(.09,"in"))) +
  ggplot2::coord_cartesian(xlim=c(.7,6.3),ylim=c(.7,1.3)) + ggplot2::theme_void()
ggplot2::ggsave("figures/chapter12/diagnostic_workflow.pdf",p0,width=7.2,height=2.2)

sd_firm <- dplyr::bind_rows(
  data.frame(model="Level two-way FE",firm=dat$firm,resid=residuals(level_lsdv)),
  data.frame(model="Growth + period FE",firm=growth$firm,resid=residuals(growth_lm))
) |> dplyr::group_by(model,firm) |> dplyr::summarise(sd=stats::sd(resid),.groups="drop")
p1 <- ggplot2::ggplot(sd_firm,ggplot2::aes(factor(firm),sd,shape=model,group=model))+ggplot2::geom_point(size=2)+ggplot2::geom_line()+ggplot2::labs(x="Firm",y="Residual standard deviation",shape=NULL)+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter12/residual_sd_firm.pdf",p1,width=7,height=4)

lag_plot_data <- function(res,firm) data.frame(firm=firm,res=res) |> dplyr::group_by(firm) |> dplyr::mutate(lag=dplyr::lag(res)) |> dplyr::ungroup() |> dplyr::filter(!is.na(lag))
zlev<-lag_plot_data(residuals(level_lsdv),dat$firm); zg<-lag_plot_data(residuals(growth_lm),growth$firm)
p2<-ggplot2::ggplot(zlev,ggplot2::aes(lag,res))+ggplot2::geom_point(alpha=.6)+ggplot2::geom_smooth(method="lm",formula=y~0+x,se=FALSE)+ggplot2::labs(x="Lagged residual",y="Current residual")+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter12/serial_level.pdf",p2,width=6.5,height=4.2)
p3<-ggplot2::ggplot(zg,ggplot2::aes(lag,res))+ggplot2::geom_point(alpha=.6)+ggplot2::geom_smooth(method="lm",formula=y~0+x,se=FALSE)+ggplot2::labs(x="Lagged residual",y="Current residual")+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter12/serial_growth.pdf",p3,width=6.5,height=4.2)

cdplot<-cd |> dplyr::mutate(stage=factor(model,levels=model))
p4<-ggplot2::ggplot(cdplot,ggplot2::aes(stage,mean.rho))+ggplot2::geom_col()+ggplot2::geom_hline(yintercept=0)+ggplot2::labs(x=NULL,y="Mean signed pairwise residual correlation")+ggplot2::theme_minimal(base_size=10)+ggplot2::theme(axis.text.x=ggplot2::element_text(angle=25,hjust=1))
ggplot2::ggsave("figures/chapter12/cd_before_after.pdf",p4,width=7,height=4.3)

hist_plot <- function(res,title) ggplot2::ggplot(data.frame(res=res),ggplot2::aes(res))+ggplot2::geom_histogram(bins=24)+ggplot2::geom_vline(xintercept=0,linetype=2)+ggplot2::labs(x="Residual",y="Count",title=title)+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter12/hist_level.pdf",hist_plot(residuals(level_lsdv),"Logged-level two-way FE residuals"),width=6.5,height=4.2)
ggplot2::ggsave("figures/chapter12/hist_growth.pdf",hist_plot(residuals(growth_lm),"Period-adjusted growth residuals"),width=6.5,height=4.2)

topg <- inf_growth[order(-inf_growth$cook),][1:20,] |> dplyr::mutate(label=paste0("F",firm,"/",year))
p5<-ggplot2::ggplot(topg,ggplot2::aes(stats::reorder(label,cook),cook))+ggplot2::geom_col()+ggplot2::geom_hline(yintercept=4/nrow(growth),linetype=2)+ggplot2::coord_flip()+ggplot2::labs(x=NULL,y="Cook's distance")+ggplot2::theme_minimal(base_size=9)
ggplot2::ggsave("figures/chapter12/influence_growth.pdf",p5,width=7,height=5)

message("Chapter 12 diagnostic benchmark reproduced successfully.")
