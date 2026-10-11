# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter21") || dir.exists("tables/chapter21"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
