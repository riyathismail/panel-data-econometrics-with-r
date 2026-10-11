# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter13") || dir.exists("tables/chapter13"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
