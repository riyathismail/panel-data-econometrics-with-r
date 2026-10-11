# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter07") || dir.exists("tables/chapter07"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
