# Transparent ADF lag selection and MacKinnon (1994) probabilities.
# Response-surface coefficients: statsmodels 0.14.5, tsa/adfvalues.py (BSD-3).
# https://github.com/statsmodels/statsmodels/blob/v0.14.5/statsmodels/tsa/adfvalues.py
# Algorithms below are expressed directly with R least squares.
mackinnon_probability <- function(stat, trend='c', N=1L) {
  stopifnot(trend %in% c('c','ct'), N %in% c(1L,3L),is.finite(stat))
  key<-paste(trend,N,sep='_')
  a<-switch(key,
    c_1=list(lo=-18.83,hi=2.74,star=-1.61,small=c(2.1659,1.4412,.038269),large=c(1.7339,.93202,-.12745,-.010368)),
    c_3=list(lo=-23.48,hi=.55,star=-3.13,small=c(3.4699,1.4856,.03164),large=c(2.5893,.45168,-.36529,-.050074)),
    ct_1=list(lo=-16.18,hi=.7,star=-2.89,small=c(3.2512,1.6047,.049588),large=c(2.5261,.61654,-.37956,-.060285)),
    ct_3=list(lo=-25.37,hi=.93,star=-3.50,small=c(4.0983,1.5173,.029898),large=c(3.221,.5255,-.32685,-.041501)))
  if(stat<a$lo) return(0)
  if(stat>a$hi) return(1)
  coeff<-if(stat<=a$star) a$small else a$large
  pnorm(sum(coeff*stat^(seq_along(coeff)-1L)))
}

adf_selected <- function(y,pmax,criterion='BIC',trend='c') {
  stopifnot(all(is.finite(y)),length(y)>pmax+5,trend %in% c('n','c','ct'))
  dy<-diff(y); ly<-head(y,-1); Tn<-length(dy)
  fit<-function(p,common=FALSE) {
    idx<-seq.int(if(common) pmax+1L else p+1L,Tn)
    z<-data.frame(dy=dy[idx],ly=ly[idx])
    if(trend=='ct') z$trend<-idx
    if(p>0) for(j in seq_len(p)) z[[paste0('dlag',j)]]<-dy[idx-j]
    lm(reformulate(setdiff(names(z),'dy'),response='dy',intercept=trend!='n'),data=z)
  }
  scores<-vapply(0:pmax,function(p) {
    m<-fit(p,TRUE); n<-nobs(m); k<-length(coef(m))
    n*log(deviance(m)/n)+(if(criterion=='AIC') 2 else log(n))*k
  },numeric(1))
  lag<-which.min(scores)-1L
  m<-fit(lag)
  stat<-unname(coef(summary(m))['ly','t value'])
  list(statistic=stat,lag=lag,nobs=nobs(m),fit=m)
}

engle_granger_case <- function(y,X) {
  stopifnot(ncol(X)==2L,length(y)==nrow(X))
  longrun<-lm(y~X)
  a<-adf_selected(residuals(longrun),pmax=1L,criterion='AIC',trend='n')
  list(statistic=a$statistic,p_value=mackinnon_probability(a$statistic,'c',3L),lag=a$lag)
}

cadf_case <- function(W,lags=0L) {
  stopifnot(is.matrix(W),all(is.finite(W)),nrow(W)>lags+5L,ncol(W)>1L)
  bar<-rowMeans(W); Tn<-nrow(W)-1L
  individual<-apply(W,2,function(y) {
    dy<-diff(y); db<-diff(bar); idx<-seq.int(lags+1L,Tn)
    z<-data.frame(dy=dy[idx],ly=head(y,-1)[idx],lybar=head(bar,-1)[idx],dybar=db[idx])
    if(lags>0L) for(j in seq_len(lags)) {
      z[[paste0('dlag',j)]]<-dy[idx-j]
      z[[paste0('barlag',j)]]<-db[idx-j]
    }
    unname(coef(summary(lm(dy~.,z)))['ly','t value'])
  })
  stopifnot(all(is.finite(individual)))
  mean(individual)
}
