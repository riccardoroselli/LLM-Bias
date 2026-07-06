#!/usr/bin/env Rscript
# =============================================================================
# run_A_crows_en.R — Experiment A -> Table 3.
# Bias detection on English CrowS-Pairs: 9 categories x 2 models. Collects the
# model responses (cached + resumable), computes per-category metrics, writes
# the table + CSV, and prints the agreement-with-the-paper summary. Dispatched
# by main.R as `A`.
# =============================================================================

# Locate the project root, then load the library.
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
}
source(file.path(.root, "src", "load_all.R"))

message("=== Experiment A: English CrowS-Pairs (Table 3) ===")
items   <- load_crows("EN")
metrics <- run_models_metrics(items, dataset_name = "crows_en", kind = "binary")

write_dataset_outputs(metrics, "table3_crows_en", "Table 3: English CrowS-Pairs")
print_metrics(metrics)
report_comparison(metrics, table_id = "table3", csv_name = "compare_table3_crows_en")

message("\nExperiment A complete.")
