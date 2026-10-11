# Chapter 22 - Difference-in-Differences and Panel Causal Inference
# Run from the RStudio Project root: source("R/chapter22.R")

required <- c("readr", "dplyr", "tidyr", "ggplot2", "fixest", "sandwich", "clubSandwich")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages in renv: ", paste(missing, collapse = ", "))
for (d in c("tables/chapter22", "results/chapter22", "figures/chapter22")) dir.create(d, recursive = TRUE, showWarnings = FALSE)

raw_file <- "data/Grunfeld_PanelData_2006_2025.csv"
dat0 <- readr::read_csv(raw_file, show_col_types = FALSE) |> dplyr::arrange(firm, year)
stopifnot(nrow(dat0) == 200L, dplyr::n_distinct(dat0$firm) == 10L, dplyr::n_distinct(dat0$year) == 20L,
          !anyDuplicated(dat0[c("firm", "year")]), !anyNA(dat0[c("invest", "value", "capital")]))

dat <- dat0 |>
  dplyr::group_by(firm) |>
  dplyr::mutate(linvest=log(invest), lvalue=log(value), lcapital=log(capital),
                dlinvest=linvest-dplyr::lag(linvest), dlvalue=lvalue-dplyr::lag(lvalue), dlcapital=lcapital-dplyr::lag(lcapital)) |>
  dplyr::ungroup() |>
  dplyr::filter(stats::complete.cases(dlinvest, dlvalue, dlcapital)) |>
  dplyr::mutate(treated_group=as.integer(firm <= 5), post=as.integer(year >= 2018),
                treatment=treated_group*post, dlinvest_sim=dlinvest + 0.08*treatment)
stopifnot(nrow(dat)==190L, sum(dat$treated_group)==95L, sum(dat$post)==80L, sum(dat$treatment)==40L)

# Explicit covariance helpers -------------------------------------------------
vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X * e, g, reorder = FALSE)
  bread <- solve(crossprod(X))
  (G/(G-1))*((n-1)/(n-k)) * bread %*% crossprod(S) %*% bread
}
vcov_2way_cr1 <- function(model, c1, c2) {
  vcov_cr1(model,c1)+vcov_cr1(model,c2)-vcov_cr1(model,interaction(c1,c2,drop=TRUE))
}
wald_F <- function(model, V, terms, df_denom) {
  b <- coef(model)[terms]; idx <- match(terms,names(coef(model))); VV <- V[idx,idx,drop=FALSE]
  W <- as.numeric(t(b) %*% solve(VV,b)); q <- length(terms); Fv <- W/q
  data.frame(F=Fv, df1=q, df2=df_denom, p.value=stats::pf(Fv,q,df_denom,lower.tail=FALSE))
}
coef_row <- function(model,V,term,df_ref,label) {
  i <- match(term,names(coef(model))); b <- coef(model)[term]; se <- sqrt(V[i,i]); t <- b/se
  crit <- stats::qt(.975,df_ref)
  data.frame(covariance=label,estimate=unname(b),std.error=se,statistic=unname(t),df=df_ref,
             p.value=2*stats::pt(abs(t),df_ref,lower.tail=FALSE),conf.low=b-crit*se,conf.high=b+crit*se)
}

# Raw two-by-two -------------------------------------------------------------
cell_means <- dat |> dplyr::group_by(treated_group,post) |> dplyr::summarise(mean=mean(dlinvest_sim),n=dplyr::n(),.groups="drop")
mu <- tidyr::pivot_wider(cell_means,id_cols=treated_group,names_from=post,values_from=mean)
raw_did <- (mu$`1`[mu$treated_group==1]-mu$`0`[mu$treated_group==1])-(mu$`1`[mu$treated_group==0]-mu$`0`[mu$treated_group==0])
stopifnot(abs(raw_did - 0.06414366906495) < 1e-12)

# Common-adoption TWFE -------------------------------------------------------
did_lm <- stats::lm(dlinvest_sim ~ treatment + dlvalue + dlcapital + factor(firm) + factor(year), data=dat)
did_fixest <- fixest::feols(dlinvest_sim ~ treatment + dlvalue + dlcapital | firm + year, data=dat)
expected <- c(treatment=0.08058999652239,dlvalue=0.484802,dlcapital=-0.105153)
stopifnot(abs(coef(did_lm)["treatment"]-expected["treatment"])<1e-10,
          abs(coef(did_lm)["dlvalue"]-expected["dlvalue"])<1e-6,
          abs(coef(did_lm)["dlcapital"]-expected["dlcapital"])<1e-6,
          abs(coef(did_fixest)["treatment"]-coef(did_lm)["treatment"])<1e-10)

V_o <- vcov(did_lm); V_f <- vcov_cr1(did_lm,dat$firm); V_p <- vcov_cr1(did_lm,dat$year); V_2 <- vcov_2way_cr1(did_lm,dat$firm,dat$year)
rows <- dplyr::bind_rows(coef_row(did_lm,V_o,"treatment",159,"Ordinary"),
                         coef_row(did_lm,V_f,"treatment",9,"Firm cluster"),
                         coef_row(did_lm,V_p,"treatment",18,"Period cluster"),
                         coef_row(did_lm,V_2,"treatment",9,"Two-way cluster"))
stopifnot(max(abs(rows$std.error-c(0.059706861187,0.057034318373,0.069887160209,0.069787004096)))<1e-9)

# Package covariance cross-check and live CR2 sensitivity.
V_f_pkg <- sandwich::vcovCL(did_lm, cluster=dat$firm, type="HC1", cadjust=TRUE)
V_p_pkg <- sandwich::vcovCL(did_lm, cluster=dat$year, type="HC1", cadjust=TRUE)
V_2_pkg <- sandwich::vcovCL(did_lm, cluster=dat[c("firm","year")], type="HC1", cadjust=TRUE)
cr2 <- clubSandwich::coef_test(did_lm, vcov="CR2", cluster=dat$firm, test="Satterthwaite", coefs="treatment")
utils::write.csv(as.data.frame(cr2),"results/chapter22/cr2_satterthwaite_live.csv",row.names=FALSE)

# Event study ----------------------------------------------------------------
dat <- dat |> dplyr::mutate(
  evt_pre5=treated_group*(year<=2013), evt_m4=treated_group*(year==2014), evt_m3=treated_group*(year==2015), evt_m2=treated_group*(year==2016),
  evt_p0=treated_group*(year==2018), evt_p1=treated_group*(year==2019), evt_p2=treated_group*(year==2020), evt_p3=treated_group*(year==2021),
  evt_p4=treated_group*(year==2022), evt_post5=treated_group*(year>=2023))
event_terms <- c("evt_pre5","evt_m4","evt_m3","evt_m2","evt_p0","evt_p1","evt_p2","evt_p3","evt_p4","evt_post5")
event_model <- stats::lm(stats::as.formula(paste("dlinvest_sim ~ dlvalue + dlcapital +",paste(event_terms,collapse=" + "),"+ factor(firm) + factor(year)")),data=dat)
V_event <- vcov_cr1(event_model,dat$firm)
event_tab <- dplyr::bind_rows(lapply(event_terms,function(z) coef_row(event_model,V_event,z,9,"Firm cluster")))
event_tab$event <- c("k<=-5","k=-4","k=-3","k=-2","k=0","k=1","k=2","k=3","k=4","k>=5")
expected_event <- c(0.041879303856,0.238210076086,-0.296444445203,0.261094048964,-0.030368622193,0.236050054653,0.162736711933,0.155429105755,0.078683498792,0.134567719088)
expected_event_se <- c(0.157258408784,0.370631595700,0.234675059580,0.208183011084,0.129814549113,0.216594385192,0.247160437877,0.215794904800,0.198870276140,0.170151547264)
stopifnot(max(abs(event_tab$estimate-expected_event))<1e-9,max(abs(event_tab$std.error-expected_event_se))<1e-9)
pretest <- wald_F(event_model,V_event,event_terms[1:4],9)
stopifnot(abs(pretest$F-2.50062550996)<1e-9,abs(pretest$p.value-0.11665552297)<1e-9)

# Separate pre-treatment differential linear-trend diagnostic ----------------
pre <- dat |> dplyr::filter(year < 2018) |> dplyr::mutate(trend = year - 2007, treated_trend = treated_group * trend)
pretrend_linear <- lm(dlinvest_sim ~ treated_trend + factor(firm) + factor(year), data = pre)
V_pretrend_linear <- vcov_cr1(pretrend_linear, pre$firm)
jpre <- match("treated_trend", names(coef(pretrend_linear)))
se_pretrend_linear <- sqrt(V_pretrend_linear[jpre,jpre])
p_pretrend_linear <- 2*stats::pt(abs(coef(pretrend_linear)["treated_trend"]/se_pretrend_linear),9,lower.tail=FALSE)
stopifnot(abs(coef(pretrend_linear)["treated_trend"] - (-0.00837178188237)) < 1e-10,
          abs(se_pretrend_linear - 0.01017454999325) < 1e-10,
          abs(p_pretrend_linear - 0.431872786611) < 1e-10)

# Exhaustive five-of-ten reassignment reference ------------------------------
assignments <- combn(1:10,5,simplify=FALSE)
assignment_beta <- vapply(assignments,function(A) {
  d <- dat; d$treatment_alt <- as.integer(d$firm %in% A)*d$post
  coef(lm(dlinvest_sim ~ treatment_alt + dlvalue + dlcapital + factor(firm)+factor(year),data=d))["treatment_alt"]
},numeric(1))
p_perm <- mean(abs(assignment_beta) >= abs(coef(did_lm)["treatment"])-1e-12)
stopifnot(length(assignment_beta)==252L,sum(abs(assignment_beta)>=abs(coef(did_lm)["treatment"])-1e-12)==48L,abs(p_perm-48/252)<1e-12)
assignment_out <- data.frame(index=seq_along(assignments),treated_firms=vapply(assignments,paste,collapse=";",FUN.VALUE=character(1)),estimate=assignment_beta)

# Exhaustive restricted firm-level wild-cluster-t reference -----------------
restricted <- lm(dlinvest_sim ~ dlvalue + dlcapital + factor(firm)+factor(year),data=dat)
signs <- expand.grid(rep(list(c(-1,1)),10)); names(signs) <- paste0("firm",1:10)
obs_t <- coef(did_lm)["treatment"]/sqrt(V_f[match("treatment",names(coef(did_lm))),match("treatment",names(coef(did_lm)))])
wild_t <- numeric(nrow(signs))
for (r in seq_len(nrow(signs))) {
  w <- unlist(signs[r,]); names(w) <- 1:10
  ystar <- fitted(restricted)+residuals(restricted)*w[as.character(dat$firm)]
  fit <- lm(ystar ~ treatment + dlvalue + dlcapital + factor(firm)+factor(year),data=dat)
  Vfstar <- vcov_cr1(fit,dat$firm); j <- match("treatment",names(coef(fit)))
  wild_t[r] <- coef(fit)["treatment"]/sqrt(Vfstar[j,j])
}
p_wild <- mean(abs(wild_t)>=abs(obs_t)-1e-12)
stopifnot(length(wild_t)==1024L,sum(abs(wild_t)>=abs(obs_t)-1e-12)==180L,abs(p_wild-0.17578125)<1e-12)

# Exports --------------------------------------------------------------------
utils::write.csv(cell_means,"tables/chapter22/raw_2x2_means.csv",row.names=FALSE)
utils::write.csv(rows,"tables/chapter22/did_covariance_sensitivity.csv",row.names=FALSE)
utils::write.csv(event_tab,"tables/chapter22/event_study_results.csv",row.names=FALSE)
utils::write.csv(pretest,"tables/chapter22/event_pretrend_test.csv",row.names=FALSE)
utils::write.csv(assignment_out,"results/chapter22/assignment_reference_distribution.csv",row.names=FALSE)
utils::write.csv(cbind(signs,t_statistic=wild_t),"results/chapter22/wild_cluster_t_distribution.csv",row.names=FALSE)
utils::write.csv(data.frame(treated_firms="1;2;3;4;5",first_treatment_teaching=2018,first_treatment_original=1947,planted_log_effect=.08,
                            n_growth=190,n_treated=95,n_control=95,n_treated_post=40,raw_did=raw_did,adjusted_did=coef(did_lm)["treatment"],
                            assignment_reference_p=p_perm,wild_cluster_t_p=p_wild),"results/chapter22/synthetic_design_manifest.csv",row.names=FALSE)

# Figures ---------------------------------------------------------------------
# Group trends.
groups <- dat |> dplyr::group_by(year,treated_group) |> dplyr::summarise(mean=mean(dlinvest_sim),.groups="drop")
p1 <- ggplot2::ggplot(groups,ggplot2::aes(year,mean,linetype=factor(treated_group)))+ggplot2::geom_line()+ggplot2::geom_point()+
  ggplot2::geom_vline(xintercept=2018,linetype=2)+ggplot2::labs(x="Teaching-period label",y="Mean synthetic investment log growth",linetype="Group")+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter22/did_group_trends.pdf",p1,width=7,height=4.2)
# Event study.
p2 <- ggplot2::ggplot(event_tab,ggplot2::aes(event,estimate,group=1))+ggplot2::geom_hline(yintercept=0)+ggplot2::geom_point()+
  ggplot2::geom_errorbar(ggplot2::aes(ymin=conf.low,ymax=conf.high),width=.15)+ggplot2::labs(x="Event time (k=-1 omitted)",y="Coefficient / 95% firm-cluster interval")+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter22/event_study.pdf",p2,width=7,height=4.2)
# Reassignment distribution.
p3 <- ggplot2::ggplot(assignment_out,ggplot2::aes(estimate))+ggplot2::geom_histogram(bins=28)+ggplot2::geom_vline(xintercept=coef(did_lm)["treatment"],linetype=2)+
  ggplot2::labs(x="TWFE treatment estimate under hypothetical reassignment",y="Count")+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter22/randomization_distribution.pdf",p3,width=7,height=4.2)
# Geometry schematic and staggered adoption conceptual figures are created as deterministic ggplot drawings.
geom <- data.frame(period=rep(c("Pre","Post"),2),group=rep(c("Control","Treated"),each=2),value=c(0,0.5,0.3,1.1))
p4 <- ggplot2::ggplot(geom,ggplot2::aes(period,value,group=group,linetype=group))+ggplot2::geom_line()+ggplot2::geom_point(size=2)+ggplot2::labs(x=NULL,y="Outcome index",linetype=NULL)+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter22/did_geometry.pdf",p4,width=7,height=4.2)
stag <- expand.grid(firm=1:6,year=1:8); cohorts <- c(3,4,5,6,Inf,Inf); stag$treated <- mapply(function(i,t) as.integer(is.finite(cohorts[i]) && t>=cohorts[i]),stag$firm,stag$year)
p5 <- ggplot2::ggplot(stag,ggplot2::aes(year,factor(firm),fill=factor(treated)))+ggplot2::geom_tile()+ggplot2::labs(x="Period",y="Firm",fill="Treated")+ggplot2::theme_minimal(base_size=10)
ggplot2::ggsave("figures/chapter22/staggered_adoption.pdf",p5,width=7,height=4.2)

writeLines(capture.output(sessionInfo()),"results/chapter22/sessionInfo.txt")
message("Chapter 22 benchmark reproduced successfully.")
