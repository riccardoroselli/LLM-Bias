######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# run_E_gender.R — Experiment E -> Table 6.
# Gender bias across three datasets: Winogender + the Gender column of EN/FR CrowS
# (reused from A/B), both models. Keep Gender rows, write table + CSV + agreement.
# main.R `E`.
######################################

# Run from the project root.
source("src/load_all.R")

message("=== Experiment E: gender bias across three datasets (Table 6) ===")

wino = load_winogender()
en   = load_crows("EN")
fr   = load_crows("FR")

m_wino = run_models_metrics(wino, dataset_name = "winogender", kind = "binary")   # new calls
m_en   = run_models_metrics(en,   dataset_name = "crows_en",   kind = "binary")   # cache hits
m_fr   = run_models_metrics(fr,   dataset_name = "crows_fr",   kind = "binary")   # cache hits

# Keep the Gender rows and stamp the Table 6 dataset label.
pick_gender = function(m, ds) {
  g = m[m$category == "Gender", , drop = FALSE]
  g$dataset = ds
  g
}
metrics_by_ds = list(winogender = m_wino, crows_en = m_en, crows_fr = m_fr)
tab6_rows = list()
for (ds in names(metrics_by_ds)) {
  tab6_rows[[length(tab6_rows) + 1L]] = pick_gender(metrics_by_ds[[ds]], ds)
}
tab6 = do.call(rbind, tab6_rows)
tab6 = tab6[order(match(tab6$model, c("chatgpt", "deepseek")),
                  match(tab6$dataset, c("winogender", "crows_en", "crows_fr"))), ]

save_results_csv(tab6, "table6_gender")
print_metrics(tab6)
report_comparison(tab6, table_id = "table6", csv_name = "compare_table6_gender")

message("\nExperiment E complete.")
