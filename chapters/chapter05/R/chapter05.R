dat<-read.csv("data/Grunfeld_PanelData_2006_2025.csv"); dat<-dat[order(dat$firm,dat$year),]
for(v in c("invest","value","capital")) dat[[paste0("l",v)]]<-log(dat[[v]])
for(v in c("invest","value","capital")){ lv<-paste0("l",v); dat[[paste0("d",lv)]]<-ave(dat[[lv]],dat$firm,FUN=function(z)c(NA,diff(z))) }
lev<-lm(linvest~lvalue+lcapital,data=dat); sh<-subset(dat,complete.cases(dlinvest,dlvalue,dlcapital)); dif<-lm(dlinvest~dlvalue+dlcapital,data=sh)
stopifnot(nrow(sh)==190,abs(summary(lev)$r.squared-0.861792115)<1e-7,abs(summary(dif)$r.squared-0.230661446)<1e-7)
