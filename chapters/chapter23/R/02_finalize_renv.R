# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter23") || dir.exists("tables/chapter23"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
