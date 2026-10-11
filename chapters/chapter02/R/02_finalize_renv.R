# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter02") || dir.exists("tables/chapter02"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
