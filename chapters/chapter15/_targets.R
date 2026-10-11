library(targets)
source("R/chapter15_functions.R")

packages <- c("readr","dplyr","tidyr","plm","lmtest","sandwich","ggplot2","modelsummary","digest")
assert_packages(packages)
tar_option_set(packages = packages)

list(
  tar_target(raw_file, "data/Grunfeld_PanelData_2006_2025.csv", format = "file"),
  tar_target(data_hash, sha256_file(raw_file)),
  tar_target(raw_data, read_validate_panel(raw_file)),
  tar_target(panel_data, transform_panel(raw_data)),
  tar_target(stationarity, stationarity_stage(panel_data)),
  tar_target(stationarity_file, export_stationarity(stationarity), format = "file"),
  tar_target(models, estimate_candidates(panel_data)),
  tar_target(selection, selection_stage(models, panel_data)),
  tar_target(diagnostics, diagnostic_stage(models)),
  tar_target(inference, final_inference_stage(models)),
  tar_target(ledger, make_decision_ledger()),
  tar_target(final_table, make_final_reporting_table(models, inference)),
  tar_target(table_files, export_tables(selection, diagnostics, inference, ledger, final_table), format = "file"),
  tar_target(figure_files, export_figures(panel_data, ledger), format = "file"),
  tar_target(hash_file, write_data_hash(data_hash), format = "file"),
  tar_target(session_file, write_session_info(), format = "file"),
  tar_target(output_manifest,
    write_pipeline_manifest(c(stationarity_file, table_files, figure_files, hash_file, session_file)),
    format = "file")
)
