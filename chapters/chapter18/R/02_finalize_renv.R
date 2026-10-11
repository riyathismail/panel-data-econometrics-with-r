# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter18") || dir.exists("tables/chapter18"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
