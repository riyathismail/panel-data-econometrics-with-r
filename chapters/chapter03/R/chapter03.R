dat<-read.csv("data/Grunfeld_PanelData_2006_2025.csv"); dat<-dat[order(dat$firm,dat$year),]
for(v in c("invest","value","capital")) dat[[paste0("l",v)]]<-log(dat[[v]])
for(v in c("invest","value","capital")){ lv<-paste0("l",v); dat[[paste0("d",lv)]]<-ave(dat[[lv]],dat$firm,FUN=function(z)c(NA,diff(z))) }
stopifnot(sum(complete.cases(dat[c("dlinvest","dlvalue","dlcapital")]))==190)
dir.create("results/chapter03",recursive=TRUE,showWarnings=FALSE); write.csv(dat,"results/chapter03/audited_panel.csv",row.names=FALSE)
