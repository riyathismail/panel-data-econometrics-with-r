if (!requireNamespace("targets",quietly=TRUE)) stop("Install targets in the renv environment first.")
targets::tar_make()
if (requireNamespace("testthat",quietly=TRUE)) testthat::test_dir("tests/testthat")
