######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# run_B_crows_fr.R — Experiment B -> Fig 2 (cross-language).
# French CrowS-Pairs + Experiment A's cached English, then the EN-vs-FR BF figure.
# Dispatched by main.R as `B`.
######################################

# Run from the project root.
source("src/load_all.R")

message("=== Experiment B: English vs French CrowS-Pairs (Fig 2) ===")

items_en = load_crows("EN")
items_fr = load_crows("FR")

m_en = run_models_metrics(items_en, dataset_name = "crows_en", kind = "binary")  # cache hits
m_fr = run_models_metrics(items_fr, dataset_name = "crows_fr", kind = "binary")  # new calls

# The paper reports no full French table (only BF curves), but we save ours too.
write_dataset_outputs(m_fr, "crows_fr", "CrowS-Pairs French (per-category metrics)")

# Assemble the cross-language BF data and draw Fig 2.
mk_df = function(m, lang) data.frame(
  model = m$model, lang = lang, category = m$category,
  log10_bf = m$log_bf10 / log(10), stringsAsFactors = FALSE
)
metrics_by_lang = list(EN = m_en, FR = m_fr)
fig_rows = list()
for (lang in names(metrics_by_lang)) {
  fig_rows[[length(fig_rows) + 1L]] = mk_df(metrics_by_lang[[lang]], lang)
}
fig_df = do.call(rbind, fig_rows)
save_results_csv(fig_df, "fig2_crosslanguage_data")
fig_crosslanguage(fig_df)

message("\nExperiment B complete.")
