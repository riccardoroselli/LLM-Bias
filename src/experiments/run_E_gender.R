#!/usr/bin/env Rscript
# =============================================================================
# run_E_gender.R — Experiment E -> Table 6.
# Gender bias across three datasets: Winogender plus the Gender column of
# English and French CrowS (reused from A/B via the cache), for both models.
# Keeps the Gender rows, writes the table + CSV + agreement summary. Dispatched
# by main.R as `E`.
# =============================================================================

# Locate the project root, then load the library.
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
}
source(file.path(.root, "src", "load_all.R"))

message("=== Experiment E: gender bias across three datasets (Table 6) ===")

wino <- load_winogender()
en   <- load_crows("EN")
fr   <- load_crows("FR")

m_wino <- run_models_metrics(wino, dataset_name = "winogender", kind = "binary")   # new calls
m_en   <- run_models_metrics(en,   dataset_name = "crows_en",   kind = "binary")   # cache hits
m_fr   <- run_models_metrics(fr,   dataset_name = "crows_fr",   kind = "binary")   # cache hits

# Keep only the Gender rows and stamp the dataset label used in Table 6.
pick_gender <- function(m, ds) {
  g <- m[m$category == "Gender", , drop = FALSE]
  g$dataset <- ds
  g
}
tab6 <- rbind(
  pick_gender(m_wino, "winogender"),
  pick_gender(m_en,   "crows_en"),
  pick_gender(m_fr,   "crows_fr")
)
tab6 <- tab6[order(match(tab6$model, c("chatgpt", "deepseek")),
                   match(tab6$dataset, c("winogender", "crows_en", "crows_fr"))), ]

save_results_csv(tab6, "table6_gender")
print_metrics(tab6)
report_comparison(tab6, table_id = "table6", csv_name = "compare_table6_gender")

message("\nExperiment E complete.")
