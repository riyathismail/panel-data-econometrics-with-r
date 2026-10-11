# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter03") || dir.exists("tables/chapter03"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
