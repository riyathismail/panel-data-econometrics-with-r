# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter09") || dir.exists("tables/chapter09"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
