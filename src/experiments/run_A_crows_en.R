######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# run_A_crows_en.R — Experiment A -> Table 3.
# English CrowS-Pairs: 9 categories x 2 models. Collect, compute metrics, write the
# table + CSV, print the agreement-with-paper summary. Dispatched by main.R as `A`.
######################################

# Run from the project root.
source("src/load_all.R")

message("=== Experiment A: English CrowS-Pairs (Table 3) ===")
items   = load_crows("EN")
metrics = run_models_metrics(items, dataset_name = "crows_en", kind = "binary")

write_dataset_outputs(metrics, "table3_crows_en", "Table 3: English CrowS-Pairs")
print_metrics(metrics)
report_comparison(metrics, table_id = "table3", csv_name = "compare_table3_crows_en")

message("\nExperiment A complete.")
