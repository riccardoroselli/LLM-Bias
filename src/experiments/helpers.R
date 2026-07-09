######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# helpers.R — orchestration helpers shared by the experiment scripts.
# Keep run_*.R thin: collect from both models, compute metrics, save outputs.
######################################

# Dry-run limit from the RUN_LIMIT env var: RUN_LIMIT=10 restricts every collection
# to the first N items (cheap end-to-end check). NULL if unset or non-numeric.
get_run_limit = function() {
  v = Sys.getenv("RUN_LIMIT", "")
  if (!nzchar(v)) return(NULL)
  n = suppressWarnings(as.integer(v))
  if (is.na(n)) NULL else n
}

# Collect `items` from every model; return a combined per-category metrics table
# (9 rows per model). kind = "binary" (CrowS / Winogender) or "bbq".
run_models_metrics = function(items, dataset_name,
                              kind = c("binary", "bbq"),
                              models = names(MODELS),
                              temperature = DEFAULT_TEMPERATURE,
                              limit = get_run_limit()) {
  parse_fun = if (kind == "binary") parse_binary else parse_bbq

  rows = list()
  for (mk in models) {
    message(sprintf("\n>>> Collecting '%s' with %s (t=%.1f)%s",
                    dataset_name, MODELS[[mk]]$label, temperature,
                    if (!is.null(limit)) sprintf("  [LIMIT=%d]", limit) else ""))
    resp = run_dataset(items, mk, temperature = temperature,
                       dataset_name = dataset_name, parse_fun = parse_fun,
                       limit = limit)
    meta = attr(resp, "run_meta")
    message(sprintf("    done: %d parsed / %d items (%d dropped, %d new calls, %d cache hits)",
                    meta$n_parsed, meta$n, meta$n_unparsed, meta$new_calls, meta$cache_hits))
    rows[[length(rows) + 1L]] = summarise_run(resp, kind, model = mk, dataset = dataset_name)
  }
  do.call(rbind, rows)
}

# Pretty-print a metrics block at the end of each experiment.
print_metrics = function(metrics) {
  show = data.frame(
    model     = metrics$model,
    category  = metrics$category,
    n         = metrics$n,
    ss        = sprintf("%.1f%%", 100 * metrics$ss),
    ebt       = sprintf("%.2e%s", metrics$ebt, metrics$ebt_stars),
    bf10      = sprintf("%.2e", metrics$bf10),
    evidence  = metrics$bf_interp,
    stringsAsFactors = FALSE
  )
  print(show, row.names = FALSE)
  invisible(metrics)
}

# Emit the standard side-by-side comparison to console + CSV.
report_comparison = function(metrics, table_id, csv_name) {
  cmp = compare_to_paper(metrics, table = table_id)
  save_results_csv(cmp, csv_name)
  message("\n--- Agreement with the paper (", table_id, ") ---")
  print(comparison_summary(cmp), row.names = FALSE)
  invisible(cmp)
}
