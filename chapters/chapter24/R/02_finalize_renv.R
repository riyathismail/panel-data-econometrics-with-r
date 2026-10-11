# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter24") || dir.exists("tables/chapter24"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
