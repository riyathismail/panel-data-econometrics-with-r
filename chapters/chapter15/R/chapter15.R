# Sequential entry point for the Chapter 15 integrated workflow.
# Run from the chapter's project directory.
source('R/chapter15_functions.R')
assert_packages(c('readr','dplyr','tidyr','plm','lmtest','sandwich',
                  'digest','ggplot2','modelsummary'))
raw_file <- 'data/Grunfeld_PanelData_2006_2025.csv'
dat <- transform_panel(read_validate_panel(raw_file))
models <- estimate_candidates(dat)
stationarity <- stationarity_stage(dat)
selection <- selection_stage(models,dat)
diagnostics <- diagnostic_stage(models)
inference <- final_inference_stage(models)
ledger <- make_decision_ledger()
report <- make_final_reporting_table(models,inference)
dir.create('results/chapter15',recursive=TRUE,showWarnings=FALSE)
files <- c(export_stationarity(stationarity),
           export_tables(selection,diagnostics,inference,ledger,report),
           export_figures(dat,ledger),
           write_data_hash(sha256_file(raw_file)),write_session_info())
write_pipeline_manifest(files)
message('Chapter 15 integrated benchmarks reproduced successfully.')
