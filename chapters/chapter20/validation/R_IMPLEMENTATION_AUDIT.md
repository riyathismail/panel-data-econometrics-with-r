# Chapter 20 R Implementation Audit

## Verified current mapping

1. `plm::pmg()` is documented as MG/DMG/CCEMG, with `model = "mg"`, `"dmg"`, or `"cmg"`. **It is not PSS pooled mean group.**
2. `plm::pcce()` is the dedicated CCEP/CCEMG interface (`model = "p"` or `"mg"`).
3. `plm::pvcm()` estimates variable-coefficient models and exposes a parameter-stability test; `plm::pooltest()` is a Chow-type poolability test. The chapter's exact interaction benchmark remains an explicit nested `lm()` comparison because common period effects must be held fixed while only the two substantive slopes are released.
4. The separate `PooledMeanGroup` CRAN package implements the Pesaran-Shin-Smith dynamic PMG estimator. Because the release benchmark must be auditable and the current package interface is old-style, the chapter uses transparent concentrated NLS in base R as its primary numerical PMG reconstruction and treats package output as a live-R cross-check.
5. Leave-one-out CCE averages are implemented explicitly; they reduce mechanical own-observation contamination but do not create large-N asymptotics.

## Runtime status
R is unavailable in the migration container. `R/chapter20.R` contains hard assertions against the independently reconstructed benchmark. Live package execution and `sessionInfo()` remain pending.
