if (!requireNamespace("renv",quietly=TRUE)) install.packages("renv",repos="https://cloud.r-project.org")
renv::init(bare=TRUE)
renv::install(c("targets","testthat","readr","dplyr","tidyr","plm","lmtest","sandwich","ggplot2","modelsummary","digest"))
message("Run run_chapter24.R and review outputs before snapshotting.")
