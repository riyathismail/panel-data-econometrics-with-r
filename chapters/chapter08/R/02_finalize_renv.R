# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter08") || dir.exists("tables/chapter08"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
