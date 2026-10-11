library(targets)
source("R/chapter24_functions.R")
packages <- c("readr","dplyr","plm","sandwich","modelsummary","digest","ggplot2")
assert_packages(packages)
tar_option_set(packages=packages)
list(
  tar_target(raw_file,"data/Grunfeld_PanelData_2006_2025.csv",format="file"),
  tar_target(data_hash,sha256_file(raw_file)),
  tar_target(raw_data,read_validate_panel(raw_file)),
  tar_target(panel_data,transform_panel(raw_data)),
  tar_target(models,estimate_capstone(panel_data)),
  tar_target(selection,selection_ledger(models)),
  tar_target(inference,inference_ledger(models)),
  tar_target(reporting,build_reporting_table(models,inference)),
  tar_target(output_files,write_outputs(selection,inference,reporting,data_hash),format="file"),
  tar_target(output_manifest,write_manifest(output_files),format="file")
)
