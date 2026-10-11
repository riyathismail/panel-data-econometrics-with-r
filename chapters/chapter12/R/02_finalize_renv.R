# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter12") || dir.exists("tables/chapter12"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
