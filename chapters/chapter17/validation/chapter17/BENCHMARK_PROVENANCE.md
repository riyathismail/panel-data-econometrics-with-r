# Engle-Granger reference provenance

The reference CSV preserves the book's rounded values. Independent statsmodels
0.14.5 calculations reproduce every statistic and probability at its printed
precision: coint(y, X, trend="c", maxlag=1, autolag="aic"). The principal R
script now computes this convention directly and checks it against the CSV;
the figure uses newly computed probabilities. The native aTSA output is a
separate sensitivity and is not forced to match these probabilities.
