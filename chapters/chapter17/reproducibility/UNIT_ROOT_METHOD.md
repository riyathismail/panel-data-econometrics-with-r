# Unit-root reference calculation

R/unit_root_helpers.R implements ordinary least squares with common-sample AIC/BIC
lag selection, followed by a refit on the chosen lag's available sample.
ADF probabilities use MacKinnon (1994) response-surface coefficients for N=1;
cointegration probabilities use the intercept response surface for N=3.
The numerical coefficients are from statsmodels 0.14.5 (BSD-3; license supplied).
https://github.com/statsmodels/statsmodels/blob/v0.14.5/statsmodels/tsa/adfvalues.py

Independent Python calculations with statsmodels 0.14.5 and pandas 2.3.3 reproduce
the book's displayed ADF/Fisher and Engle-Granger tables. The R implementation was
then compared against the full-precision independent outputs. Asymptotic
cointegration probabilities and finite-sample critical values can disagree in
this short sample; Chapter 17 explicitly discloses firm 7's borderline evidence.
