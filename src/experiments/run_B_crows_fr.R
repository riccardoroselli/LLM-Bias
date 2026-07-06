#!/usr/bin/env Rscript
# =============================================================================
# run_B_crows_fr.R — Experiment B -> Fig 2 (cross-language).
# Runs the French CrowS-Pairs and reuses Experiment A's cached English
# responses, then draws the English-vs-French Bayes-factor figure. Dispatched
# by main.R as `B`.
# =============================================================================

# Locate the project root, then load the library.
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
}
source(file.path(.root, "src", "load_all.R"))

message("=== Experiment B: English vs French CrowS-Pairs (Fig 2) ===")

items_en <- load_crows("EN")
items_fr <- load_crows("FR")

m_en <- run_models_metrics(items_en, dataset_name = "crows_en", kind = "binary")  # cache hits
m_fr <- run_models_metrics(items_fr, dataset_name = "crows_fr", kind = "binary")  # new calls

# The paper reports no full French table (only BF curves), but we save ours too.
write_dataset_outputs(m_fr, "crows_fr", "CrowS-Pairs French (per-category metrics)")

# Assemble the cross-language BF data and draw Fig 2.
mk_df <- function(m, lang) data.frame(
  model = m$model, lang = lang, category = m$category,
  log10_bf = m$log_bf10 / log(10), stringsAsFactors = FALSE
)
fig_df <- rbind(mk_df(m_en, "EN"), mk_df(m_fr, "FR"))
save_results_csv(fig_df, "fig2_crosslanguage_data")
fig_crosslanguage(fig_df)

message("\nExperiment B complete.")
