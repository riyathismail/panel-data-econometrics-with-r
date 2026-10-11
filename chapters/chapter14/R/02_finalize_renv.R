# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter14") || dir.exists("tables/chapter14"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
