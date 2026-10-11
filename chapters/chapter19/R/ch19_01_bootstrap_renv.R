if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos="https://cloud.r-project.org")
renv::init(bare = TRUE)
renv::install(c("readr","dplyr","tidyr","ggplot2","plm","lmtest","sandwich","panelvar"))
renv::snapshot()
