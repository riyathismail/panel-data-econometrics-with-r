capstone_root <- if (file.exists("R/chapter24_functions.R")) "." else "../.."
source(file.path(capstone_root,"R/chapter24_functions.R"))
dat <- transform_panel(read_validate_panel(file.path(capstone_root,"data/Grunfeld_PanelData_2006_2025.csv")))
models <- estimate_capstone(dat)
inf <- inference_ledger(models)
testthat::test_that("panel accounting is fixed", {
  testthat::expect_equal(nrow(dat),200L)
  testthat::expect_equal(nrow(models$short),190L)
})
testthat::test_that("principal coefficients match release benchmark", {
  testthat::expect_equal(unname(coef(models$growth_period)["dlvalue"]),0.495709423973,tolerance=1e-10)
  testthat::expect_equal(unname(coef(models$growth_period)["dlcapital"]),-0.0856926114420,tolerance=1e-10)
})
testthat::test_that("period clustered standard errors match", {
  p <- inf[inf$covariance=="Period cluster",]
  testthat::expect_equal(p$std.error[p$term=="dlvalue"],0.0743364623111,tolerance=1e-10)
  testthat::expect_equal(p$std.error[p$term=="dlcapital"],0.0419266496362,tolerance=1e-10)
})
testthat::test_that("finite log change is reproducible", {
  testthat::expect_equal(finite_change(0.495709423973,0.10),4.838004060655,tolerance=1e-5)
})
