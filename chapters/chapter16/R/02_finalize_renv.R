# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter16") || dir.exists("tables/chapter16"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
