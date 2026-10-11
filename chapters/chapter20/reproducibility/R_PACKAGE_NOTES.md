# Chapter 20 R package mapping

- `plm::pmg(model="mg")`: Mean Group (MG).
- `plm::pmg(model="dmg")`: demeaned Mean Group (DMG).
- `plm::pmg(model="cmg")`: Common Correlated Effects Mean Group (CCEMG).
- `plm::pcce(model="p")`: pooled CCE (CCEP).
- `plm::pcce(model="mg")`: CCEMG through the dedicated CCE interface.
- `plm::pvcm()` / `plm::pooltest()`: variable-coefficient and poolability tools; these are useful cross-checks but do not replace the exact 18-restriction benchmark with common period effects used in this chapter.
- `PooledMeanGroup`: separate CRAN package implementing the Pesaran-Shin-Smith pooled mean group estimator. Its current CRAN release is old-style and is treated as a secondary software cross-check.
- Base R `optim()` plus `numDeriv::jacobian()`: transparent release benchmark for the PSS long-run pooling restriction and teaching NLS covariance.

Do not call `plm::pmg()` a pooled mean group estimator.
