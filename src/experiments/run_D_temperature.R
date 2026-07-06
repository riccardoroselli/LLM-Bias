#!/usr/bin/env Rscript
# =============================================================================
# run_D_temperature.R — Experiment D -> Table 5 + Fig 3 (robustness study).
# BBQ Sexual-orientation subset (n=216), ChatGPT only. Queries the subset once
# per temperature {0, 0.5, 1, 1.5, 2}, then recomputes the statistics on nested
# prefix subsamples {5,10,20,50,80,100}% (no extra calls) to show how the test
# behaves vs sample size and temperature. Temperature 1.0 reuses Experiment C's
# cached responses. Dispatched by main.R as `D`.
# =============================================================================

# Locate the project root, then load the library.
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
}
source(file.path(.root, "src", "load_all.R"))

message("=== Experiment D: temperature x sample size (Table 5, Fig 3) ===")

items <- load_bbq("Sexual orientation")
N     <- nrow(items)                      # 216
limit <- get_run_limit()

rows <- list()
for (temp in TEMPERATURES_ROBUSTNESS) {
  # dataset_name = "bbq" so temp=1.0 reuses Experiment C's cached responses.
  resp <- run_dataset(items, "chatgpt", temperature = temp,
                      dataset_name = "bbq", parse_fun = parse_bbq, limit = limit)
  resp <- add_stereo_indicator(resp, kind = "bbq")

  for (frac in SUBSAMPLE_FRACTIONS) {
    m   <- max(1L, floor(frac * N))                 # nominal subsample size
    sub <- resp[seq_len(min(m, nrow(resp))), , drop = FALSE]
    ok  <- !is.na(sub$x)
    n   <- sum(ok); k <- sum(sub$x[ok])
    met <- compute_metrics_nk(n, k)
    rows[[length(rows) + 1L]] <- data.frame(
      temperature = temp, fraction = frac, pct = paste0(round(100 * frac), "%"),
      sample_size = m, n = n, k = k,
      ss = met$ss, ebt = met$ebt, ebt_stars = met$ebt_stars,
      log_bf10 = met$log_bf10, bf10 = met$bf10, bf_strength = met$bf_strength,
      stringsAsFactors = FALSE
    )
  }
}
tab5 <- do.call(rbind, rows)
save_results_csv(tab5, "table5_temperature")

# --- Paper-style markdown (percentages as columns, temperature blocks) --------
.ensure_dir <- function(d) if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
.ensure_dir(PATHS$tables)
pcts  <- paste0(round(100 * SUBSAMPLE_FRACTIONS), "%")
lines <- c(paste0("**Table 5 (reproduction): BBQ Sexual orientation, ChatGPT-3.5-Turbo**"), "",
           paste0("| Percentage | ", paste(pcts, collapse = " | "), " |"),
           paste0("| --- | ", paste(rep("---", length(pcts)), collapse = " | "), " |"))
for (temp in TEMPERATURES_ROBUSTNESS) {
  blk <- tab5[tab5$temperature == temp, , drop = FALSE]
  blk <- blk[match(SUBSAMPLE_FRACTIONS, blk$fraction), ]
  lines <- c(lines,
    paste0("| **Temperature = ", formatC(temp, format = "f", digits = 1), "** | ",
           paste(rep("", length(pcts)), collapse = " | "), " |"),
    paste0("| SS | ",  paste(sprintf("%.1f%%", 100 * blk$ss), collapse = " | "), " |"),
    paste0("| EBT | ", paste(sprintf("%.2e%s", blk$ebt, blk$ebt_stars), collapse = " | "), " |"),
    paste0("| BF | ",  paste(sprintf("%.2e", blk$bf10), collapse = " | "), " |"))
}
writeLines(lines, file.path(PATHS$tables, "table5_temperature.md"))
message("Wrote ", file.path(PATHS$tables, "table5_temperature.md"))

# --- Fig 3 --------------------------------------------------------------------
fig_df <- data.frame(temperature = tab5$temperature, sample_size = tab5$sample_size,
                     log10_bf = tab5$log_bf10 / log(10), ebt = tab5$ebt)
fig_temperature(fig_df)

message("\nExperiment D complete.")
