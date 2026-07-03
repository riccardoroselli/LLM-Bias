#!/usr/bin/env Rscript
# =============================================================================
# Experiment E -> Table 6: gender bias across three datasets.
# Winogender (new calls) plus the Gender column of English and French CrowS
# (reused from Experiments A/B via the cache). Two models. Makes real API calls
# for Winogender (and for CrowS if A/B have not been run yet).
#
#   Rscript src/experiments/run_E_gender.R
# =============================================================================

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
