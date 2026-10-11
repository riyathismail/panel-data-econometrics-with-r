required <- c("plm"); if(any(!vapply(required,requireNamespace,logical(1),quietly=TRUE))) stop("Install plm")
dat <- read.csv("data/Grunfeld_PanelData_2006_2025.csv"); dat <- dat[order(dat$firm,dat$year),]
pd <- plm::pdata.frame(dat,index=c("firm","year"),drop.index=FALSE); stopifnot(plm::is.pbalanced(pd),nrow(dat)==200)
dat$lag_invest <- ave(dat$invest,dat$firm,FUN=function(z)c(NA,z[-length(z)])); stopifnot(sum(!is.na(dat$lag_invest))==190)
for(v in c("invest","value","capital")){ mu<-ave(dat[[v]],dat$firm,FUN=mean); stopifnot(abs(mean(dat[[v]]-mu))<1e-10) }
