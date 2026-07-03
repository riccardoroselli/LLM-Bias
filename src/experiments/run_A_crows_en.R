#!/usr/bin/env Rscript
# =============================================================================
# Experiment A -> Table 3: bias detection on English CrowS-Pairs.
# Nine categories, two models. Makes real (cached, resumable) API calls.
#
#   Rscript src/experiments/run_A_crows_en.R          # full run
#   RUN_LIMIT=10 Rscript src/experiments/run_A_crows_en.R   # small-sample check
# =============================================================================

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
