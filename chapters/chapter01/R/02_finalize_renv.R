# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter01") || dir.exists("tables/chapter01"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
