######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# run_C_bbq.R — Experiment C -> Table 4.
# BBQ (ambiguous + negative): 9 categories x 2 models, the largest run (~7839 items
# x 2). Load + resolve, collect, write table + CSV + agreement. main.R `C`.
######################################

# Run from the project root.
source("src/load_all.R")

message("=== Experiment C: BBQ (Table 4) ===")
message("Loading + resolving BBQ items for all nine categories ...")
parts = list()
for (cat in CATEGORIES) {
  parts[[length(parts) + 1L]] = load_bbq(cat)
}
items = do.call(rbind, parts)
message(sprintf("  %d resolved items across %d categories.",
                nrow(items), length(unique(items$category))))

metrics = run_models_metrics(items, dataset_name = "bbq", kind = "bbq")

write_dataset_outputs(metrics, "table4_bbq", "Table 4: BBQ")
print_metrics(metrics)
report_comparison(metrics, table_id = "table4", csv_name = "compare_table4_bbq")

message("\nExperiment C complete.")
