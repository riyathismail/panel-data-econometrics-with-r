# Environment Target

The publisher release should record the R version, platform, CRAN repository, package versions, `sessionInfo()`, and a real `renv.lock`. The lockfile is generated only after the targets pipeline and test suite pass in the production R environment.
