# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter05") || dir.exists("tables/chapter05"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
