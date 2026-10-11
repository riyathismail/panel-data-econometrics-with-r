# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter19") || dir.exists("tables/chapter19"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
