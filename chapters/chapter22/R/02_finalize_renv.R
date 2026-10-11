# Verify outputs without overwriting the released dependency versions.
stopifnot(dir.exists("results/chapter22") || dir.exists("tables/chapter22"))
if (dir.exists("tests/testthat")) testthat::test_dir("tests/testthat")
renv::status()
