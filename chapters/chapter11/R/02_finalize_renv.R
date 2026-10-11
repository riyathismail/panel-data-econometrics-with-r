# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter11") || dir.exists("tables/chapter11"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
