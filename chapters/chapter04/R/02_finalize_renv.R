# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter04") || dir.exists("tables/chapter04"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
