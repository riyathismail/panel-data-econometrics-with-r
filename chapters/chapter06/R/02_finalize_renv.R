# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter06") || dir.exists("tables/chapter06"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
