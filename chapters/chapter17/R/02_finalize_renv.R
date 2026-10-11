# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter17") || dir.exists("tables/chapter17"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
