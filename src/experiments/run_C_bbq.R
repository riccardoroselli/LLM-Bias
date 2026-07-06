#!/usr/bin/env Rscript
# =============================================================================
# run_C_bbq.R — Experiment C -> Table 4.
# Bias detection on BBQ (ambiguous + negative questions): 9 categories x 2
# models. The largest run (~7839 items x 2 models), cached + resumable. Loads
# and resolves the BBQ items, collects responses, and writes the table + CSV +
# agreement summary. Dispatched by main.R as `C`.
# =============================================================================

# Locate the project root, then load the library.
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
}
source(file.path(.root, "src", "load_all.R"))

message("=== Experiment C: BBQ (Table 4) ===")
message("Loading + resolving BBQ items for all nine categories ...")
items <- do.call(rbind, lapply(CATEGORIES, load_bbq))
message(sprintf("  %d resolved items across %d categories.",
                nrow(items), length(unique(items$category))))

metrics <- run_models_metrics(items, dataset_name = "bbq", kind = "bbq")

write_dataset_outputs(metrics, "table4_bbq", "Table 4: BBQ")
print_metrics(metrics)
report_comparison(metrics, table_id = "table4", csv_name = "compare_table4_bbq")

message("\nExperiment C complete.")
