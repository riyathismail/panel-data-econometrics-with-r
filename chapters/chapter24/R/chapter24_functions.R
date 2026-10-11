# Chapter 24 - Final Capstone and Comprehensive Review
# Reusable functions for the production targets graph.

assert_packages <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Install required packages in the renv environment: ", paste(missing, collapse=", "))
  invisible(TRUE)
}
sha256_file <- function(path) digest::digest(file=path, algo="sha256", serialize=FALSE)

read_validate_panel <- function(path) {
  dat <- readr::read_csv(path, show_col_types=FALSE) |> dplyr::arrange(firm, year)
  req <- c("firm","year","invest","value","capital")
  stopifnot(identical(names(dat), req), nrow(dat)==200L,
            dplyr::n_distinct(dat$firm)==10L, dplyr::n_distinct(dat$year)==20L,
            !anyDuplicated(dat[c("firm","year")]), !anyNA(dat[req]),
            all(dat$invest>0), all(dat$value>0), all(dat$capital>0))
  dat
}

transform_panel <- function(dat) {
  out <- dat |>
    dplyr::group_by(firm) |>
    dplyr::mutate(
      linvest=log(invest), lvalue=log(value), lcapital=log(capital),
      dlinvest=linvest-dplyr::lag(linvest),
      dlvalue=lvalue-dplyr::lag(lvalue),
      dlcapital=lcapital-dplyr::lag(lcapital),
      ginvest_pct=100*dlinvest, gvalue_pct=100*dlvalue, gcapital_pct=100*dlcapital
    ) |> dplyr::ungroup()
  first <- min(out$year)
  stopifnot(all(is.na(out$dlinvest[out$year==first])),
            all(is.na(out$dlvalue[out$year==first])),
            all(is.na(out$dlcapital[out$year==first])),
            sum(stats::complete.cases(out[c("dlinvest","dlvalue","dlcapital")]))==190L)
  out
}

vcov_cr1 <- function(model, cluster) {
  X <- stats::model.matrix(model); e <- stats::residuals(model)
  n <- nrow(X); k <- ncol(X); g <- as.factor(cluster); G <- nlevels(g)
  S <- rowsum(X*e, g, reorder=FALSE)
  bread <- solve(crossprod(X))
  correction <- (G/(G-1))*((n-1)/(n-k))
  correction * bread %*% crossprod(S) %*% bread
}
vcov_2way_cr1 <- function(model, c1, c2) {
  vcov_cr1(model,c1) + vcov_cr1(model,c2) - vcov_cr1(model,interaction(c1,c2,drop=TRUE))
}

nested_f <- function(restricted, unrestricted) {
  q <- stats::df.residual(restricted)-stats::df.residual(unrestricted)
  F <- ((deviance(restricted)-deviance(unrestricted))/q)/(deviance(unrestricted)/stats::df.residual(unrestricted))
  data.frame(F=F, df1=q, df2=stats::df.residual(unrestricted), p.value=stats::pf(F,q,stats::df.residual(unrestricted),lower.tail=FALSE))
}

estimate_capstone <- function(dat) {
  pdata <- plm::pdata.frame(dat,index=c("firm","year"),drop.index=FALSE)
  short <- dat |> dplyr::filter(stats::complete.cases(dlinvest,dlvalue,dlcapital))
  models <- list(
    pool_lm=stats::lm(linvest~lvalue+lcapital,data=dat),
    firm_lsdv=stats::lm(linvest~lvalue+lcapital+factor(firm),data=dat),
    time_lsdv=stats::lm(linvest~lvalue+lcapital+factor(year),data=dat),
    twoway_lsdv=stats::lm(linvest~lvalue+lcapital+factor(firm)+factor(year),data=dat),
    pool_plm=plm::plm(linvest~lvalue+lcapital,data=pdata,model="pooling"),
    fe_plm=plm::plm(linvest~lvalue+lcapital,data=pdata,model="within",effect="individual"),
    re_plm=plm::plm(linvest~lvalue+lcapital,data=pdata,model="random",effect="individual",random.method="swar"),
    growth_pool=stats::lm(dlinvest~dlvalue+dlcapital,data=short),
    growth_firm=stats::lm(dlinvest~dlvalue+dlcapital+factor(firm),data=short),
    growth_period=stats::lm(dlinvest~dlvalue+dlcapital+factor(year),data=short),
    short=short,
    pdata=pdata
  )
  stopifnot(abs(coef(models$growth_period)["dlvalue"]-0.495709423973)<1e-10,
            abs(coef(models$growth_period)["dlcapital"]-(-0.0856926114420))<1e-10,
            abs(summary(models$growth_period)$r.squared-0.492530736506)<1e-10)
  models
}

selection_ledger <- function(models) {
  f_pool_fe <- nested_f(models$pool_lm,models$firm_lsdv)
  f_fd_firm <- nested_f(models$growth_pool,models$growth_firm)
  f_fd_period <- nested_f(models$growth_pool,models$growth_period)
  lm_bp <- plm::plmtest(models$pool_plm,effect="individual",type="bp")
  hausman <- plm::phtest(models$fe_plm,models$re_plm)
  stopifnot(abs(f_pool_fe$F-52.2846454431)<1e-8,
            abs(unname(lm_bp$statistic)-754.636423561)<1e-5,
            abs(unname(hausman$statistic)-7.715151276)<1e-5,
            abs(f_fd_firm$F-0.1940741505)<1e-8,
            abs(f_fd_period$F-4.8449469749)<1e-8)
  dplyr::bind_rows(
    data.frame(test="Pooled levels vs firm FE",statistic=f_pool_fe$F,df="9,188",p.value=f_pool_fe$p.value),
    data.frame(test="Pooled levels vs random component",statistic=unname(lm_bp$statistic),df="1",p.value=lm_bp$p.value),
    data.frame(test="FE vs RE Hausman",statistic=unname(hausman$statistic),df="2",p.value=hausman$p.value),
    data.frame(test="Growth additional firm effects",statistic=f_fd_firm$F,df="9,178",p.value=f_fd_firm$p.value),
    data.frame(test="Growth period effects",statistic=f_fd_period$F,df="18,169",p.value=f_fd_period$p.value)
  )
}

inference_ledger <- function(models) {
  m <- models$growth_period; short <- models$short
  Vfirm <- vcov_cr1(m,short$firm); Vperiod <- vcov_cr1(m,short$year); V2 <- vcov_2way_cr1(m,short$firm,short$year)
  make <- function(V,df,label) {
    terms <- c("dlvalue","dlcapital"); b <- coef(m)[terms]; se <- sqrt(diag(V)[terms]); crit <- stats::qt(.975,df)
    data.frame(covariance=label,term=terms,estimate=unname(b),std.error=unname(se),
               statistic=unname(b/se),p.value=2*stats::pt(abs(b/se),df,lower.tail=FALSE),
               conf.low=unname(b-crit*se),conf.high=unname(b+crit*se),df.reference=df)
  }
  out <- dplyr::bind_rows(make(Vfirm,9,"Firm cluster"),make(Vperiod,18,"Period cluster"),make(V2,9,"Two-way cluster"))
  expected <- c(0.138414508506,0.0401240022053,0.0743364623111,0.0419266496362,0.120338033149,0.0412292913853)
  stopifnot(max(abs(out$std.error-expected))<1e-10)
  out
}

build_reporting_table <- function(models,inference) {
  primary <- inference[inference$covariance=="Period cluster",]
  primary[,c("term","estimate","std.error","statistic","p.value","conf.low","conf.high")]
}

finite_change <- function(beta,r) 100*((1+r)^beta-1)

write_outputs <- function(selection,inference,reporting,data_hash) {
  dir.create("tables/chapter24",recursive=TRUE,showWarnings=FALSE)
  dir.create("results/chapter24",recursive=TRUE,showWarnings=FALSE)
  utils::write.csv(selection,"tables/chapter24/model_selection_ledger.csv",row.names=FALSE)
  utils::write.csv(inference,"tables/chapter24/inference_sensitivity.csv",row.names=FALSE)
  utils::write.csv(reporting,"tables/chapter24/final_reporting_table.csv",row.names=FALSE)
  modelsummary::datasummary_df(reporting,output="tables/chapter24/final_reporting_table.tex",title="Capstone short-run panel-regression result")
  writeLines(data_hash,"results/chapter24/raw_data_sha256.txt")
  writeLines(capture.output(sessionInfo()),"results/chapter24/sessionInfo.txt")
  c("tables/chapter24/model_selection_ledger.csv","tables/chapter24/inference_sensitivity.csv","tables/chapter24/final_reporting_table.csv","tables/chapter24/final_reporting_table.tex","results/chapter24/raw_data_sha256.txt","results/chapter24/sessionInfo.txt")
}

write_manifest <- function(files) {
  x <- data.frame(file=files,sha256=vapply(files,sha256_file,character(1)))
  utils::write.csv(x,"results/chapter24/output_manifest.csv",row.names=FALSE)
  "results/chapter24/output_manifest.csv"
}
