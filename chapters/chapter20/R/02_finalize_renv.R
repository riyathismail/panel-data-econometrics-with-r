# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter20") || dir.exists("tables/chapter20"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
