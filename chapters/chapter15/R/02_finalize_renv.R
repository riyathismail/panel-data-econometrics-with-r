# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter15") || dir.exists("tables/chapter15"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
