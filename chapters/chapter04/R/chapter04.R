# Execute the stated chapter case tests, rather than only constructing pdata.
library(plm)
source('R/unit_root_helpers.R')
dat<-read.csv('data/Grunfeld_PanelData_2006_2025.csv')
dat<-dat[order(dat$firm,dat$year),]
for(v in c('invest','value','capital')) dat[[paste0('l',v)]]<-log(dat[[v]])
pd<-plm::pdata.frame(dat,index=c('firm','year'))
stopifnot(plm::is.pbalanced(pd),nrow(dat)==200,!anyDuplicated(dat[c('firm','year')]))
for(f in c('results','tables','figures')) dir.create(paste0(f,'/chapter04'),recursive=TRUE,showWarnings=FALSE)
individual<-list(); cips<-list()
for(v in c('invest','value','capital')) {
  W<-as.matrix(xtabs(as.formula(paste0('l',v,'~year+firm')),dat))
  for(difference in c(FALSE,TRUE)) {
    Z<-if(difference) apply(W,2,diff) else W
    for(trend in if(difference) 'c' else c('c','ct')) {
      for(i in seq_len(ncol(Z))) {
        a<-adf_selected(Z[,i],pmax=if(difference) 1L else 2L,criterion='BIC',trend=trend)
        individual[[length(individual)+1L]]<-data.frame(variable=v,difference=difference,trend=trend,firm=i,
          statistic=a$statistic,p_value=mackinnon_probability(a$statistic,trend),lag=a$lag)
      }
    }
    for(p in 0:1) cips[[length(cips)+1L]]<-data.frame(variable=v,difference=difference,lag=p,CIPS=cadf_case(Z,p),T_input=nrow(Z))
  }
}
individual<-do.call(rbind,individual);cips<-do.call(rbind,cips)
summaries<-lapply(split(individual,interaction(individual$variable,individual$difference,individual$trend,drop=TRUE)),function(z) {
  F<--2*sum(log(z$p_value))
  data.frame(variable=z$variable[1],difference=z$difference[1],trend=z$trend[1],Fisher=F,p_value=pchisq(F,20,lower.tail=FALSE),reject5=sum(z$p_value<.05),reject10=sum(z$p_value<.1))
})
fisher<-do.call(rbind,summaries)
write.csv(individual,'tables/chapter04/adf_individual.csv',row.names=FALSE)
write.csv(fisher,'tables/chapter04/fisher_adf.csv',row.names=FALSE)
write.csv(cips,'tables/chapter04/cips_case.csv',row.names=FALSE)
expected<-c(invest=16.751,value=71.248,capital=38.139)
z<-subset(fisher,!difference & trend=='c')
stopifnot(max(abs(z$Fisher-expected[z$variable]))<.0005)
expectedD<-c(invest=214.430,value=230.331,capital=150.399)
z<-subset(fisher,difference & trend=='c')
stopifnot(max(abs(z$Fisher-expectedD[z$variable]))<.0005)
z<-subset(cips,!difference & lag==0)
stopifnot(max(abs(z$CIPS-c(invest=-2.336,value=-2.414,capital=-3.438)[z$variable]))<.0005)
# Native examples use explicit short-panel lag settings. Their output conventions
# are recorded separately from the MacKinnon/BIC reference calculation above.
native<-list(
 LLC=plm::purtest(pd$linvest,test='levinlin',exo='intercept',lags='SIC',pmax=2),
 IPS=plm::purtest(pd$linvest,test='ips',exo='intercept',lags='SIC',pmax=2),
 Fisher=plm::purtest(pd$linvest,test='madwu',exo='intercept',lags='SIC',pmax=2),
 Hadri=plm::purtest(pd$linvest,test='hadri',exo='intercept'),
 CIPS_lag1=plm::cipstest(pd$linvest,lags=1L,type='drift',model='cmg'))
writeLines(capture.output(native),'results/chapter04/native_package_tests.txt')
writeLines(capture.output(sessionInfo()),'results/chapter04/sessionInfo.txt')
message('Chapter 4 Fisher/ADF and CADF case calculations reproduced; native tests exported.')
