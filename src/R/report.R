######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# report.R — result tables and figures.
# Sections:  [1] tables (CSV + markdown)   [2] figures (Fig 2 & Fig 3, ggplot2)
######################################

#### Section 1: tables ####
# Two outputs: tidy CSVs in data/results/ (source of truth), and markdown tables in
# outputs/tables/ laid out like the paper's Tables 3/4/6 (categories as columns,
# SS / EBT / BF as rows) for the slides.

ensure_dir = function(d) if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Save a tidy metrics/comparison data.frame as CSV under data/results/.
save_results_csv = function(df, name) {
  ensure_dir(PATHS$results)
  path = file.path(PATHS$results, paste0(name, ".csv"))
  utils::write.csv(df, path, row.names = FALSE)
  message("Wrote ", path)
  invisible(path)
}

# Format a Bayes factor: scientific, with the paper's emphasis (**bold** = strong,
# _italic_ = moderate).
fmt_bf = function(bf, strength) {
  s = formatC(bf, format = "e", digits = 2)
  if (isTRUE(strength == "strong"))   paste0("**", s, "**")
  else if (isTRUE(strength == "moderate")) paste0("_", s, "_")
  else s
}
fmt_ebt = function(p, stars) paste0(formatC(p, format = "e", digits = 2), stars)
fmt_ss  = function(ss) paste0(formatC(100 * ss, format = "f", digits = 2), "%")

# Paper-style wide markdown table for one model+dataset (9 category rows from
# summarise_run()). Returns a character vector of markdown lines.
metrics_to_markdown = function(metrics, caption = NULL) {
  metrics = metrics[order(match(metrics$category, CATEGORIES)), , drop = FALSE]
  short   = unname(CATEGORY_SHORT[metrics$category])
  headers = paste0(short, " (", metrics$n, ")")

  line_header = paste0("| Method | ", paste(headers, collapse = " | "), " |")
  line_sep    = paste0("| --- | ", paste(rep("---", length(headers)), collapse = " | "), " |")
  line_ss  = paste0("| SS | ",  paste(fmt_ss(metrics$ss), collapse = " | "), " |")
  line_ebt = paste0("| EBT | ", paste(mapply(fmt_ebt, metrics$ebt, metrics$ebt_stars), collapse = " | "), " |")
  line_bf  = paste0("| BF | ",  paste(mapply(fmt_bf, metrics$bf10, metrics$bf_strength), collapse = " | "), " |")

  out = c(line_header, line_sep, line_ss, line_ebt, line_bf)
  if (!is.null(caption)) out = c(paste0("**", caption, "**"), "", out)
  out
}

# Write a markdown table file for one model+dataset metrics table.
write_markdown_table = function(metrics, name, caption = NULL) {
  ensure_dir(PATHS$tables)
  path = file.path(PATHS$tables, paste0(name, ".md"))
  writeLines(metrics_to_markdown(metrics, caption), path)
  message("Wrote ", path)
  invisible(path)
}

# Write one markdown file per model plus the tidy CSV, from a multi-model table.
write_dataset_outputs = function(metrics, dataset_label, table_caption) {
  save_results_csv(metrics, paste0("metrics_", dataset_label))
  for (mk in unique(metrics$model)) {
    sub = metrics[metrics$model == mk, , drop = FALSE]
    cap = paste0(table_caption, " — ", MODELS[[mk]]$label)
    write_markdown_table(sub, paste0(dataset_label, "_", mk), cap)
  }
  invisible(NULL)
}

#### Section 2: figures ####
# The paper's two figures, via ggplot2. Fig 2 (fig_crosslanguage): log10(BF) per
# category, English (solid) vs French (dashed), one colour per model. Fig 3
# (fig_temperature): the temperature x sample-size study on BBQ Sex.Ori. (ChatGPT).
# Both take tidy data.frames and write a PNG under outputs/figures/.

# ---- Fig 2: cross-language Bayes factors ----
# `df` columns: model (chr), lang ("EN"/"FR"), category (chr), log10_bf (num).
fig_crosslanguage = function(df, outfile = "fig2_crosslanguage.png",
                             width = 9, height = 5.5, dpi = 150) {
  library(ggplot2)
  ensure_dir(PATHS$figures)

  df$category = factor(df$category, levels = CATEGORIES)
  df$lang     = factor(df$lang, levels = c("EN", "FR"))
  df$model_label = vapply(df$model, function(m) MODELS[[m]]$label, character(1))

  p = ggplot(df, aes(x = .data$category, y = .data$log10_bf,
                     colour = .data$model_label,
                     linetype = .data$lang,
                     group = interaction(.data$model, .data$lang))) +
    geom_hline(yintercept = 0,  colour = "grey40", linetype = "dotdash") +
    geom_hline(yintercept = 1,  colour = "grey70", linetype = "dotted") +
    geom_hline(yintercept = -1, colour = "grey70", linetype = "dotted") +
    geom_line() +
    geom_point(size = 1.6) +
    labs(
      title = "Bayes factors across bias categories: English vs French CrowS-Pairs",
      x = NULL, y = expression(log[10](BF[10])),
      colour = "Model", linetype = "Language"
    ) +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 35, hjust = 1))

  path = file.path(PATHS$figures, outfile)
  ggsave(path, p, width = width, height = height, dpi = dpi)
  message("Wrote ", path)
  invisible(path)
}

# ---- Fig 3: temperature x sample-size robustness ----
# `df` columns: temperature (num), sample_size (int), log10_bf (num), ebt (num).
fig_temperature = function(df, outfile = "fig3_temperature.png",
                           width = 10, height = 5, dpi = 150) {
  library(ggplot2)
  ensure_dir(PATHS$figures)

  # Long form + panel var so we can facet BF and p-value side by side.
  long = rbind(
    data.frame(temperature = df$temperature, sample_size = df$sample_size,
               panel = "log10(BF10)", value = df$log10_bf, stringsAsFactors = FALSE),
    data.frame(temperature = df$temperature, sample_size = df$sample_size,
               panel = "EBT p-value", value = df$ebt, stringsAsFactors = FALSE)
  )
  long$panel       = factor(long$panel, levels = c("log10(BF10)", "EBT p-value"))
  long$temperature = factor(long$temperature)

  # Reference lines: BF thresholds on the BF panel, 0.05 on the p-value panel.
  hlines = rbind(
    data.frame(panel = "log10(BF10)", yintercept = c(-1, 0, 1)),
    data.frame(panel = "EBT p-value", yintercept = 0.05)
  )
  hlines$panel = factor(hlines$panel, levels = c("log10(BF10)", "EBT p-value"))

  p = ggplot(long, aes(x = .data$sample_size, y = .data$value,
                       colour = .data$temperature,
                       group = .data$temperature)) +
    geom_hline(data = hlines,
               aes(yintercept = .data$yintercept),
               colour = "grey60", linetype = "dashed", inherit.aes = FALSE) +
    geom_line() +
    geom_point(size = 1.4) +
    facet_wrap(~ panel, scales = "free_y") +
    labs(
      title = "Robustness of BF vs p-value to sample size and temperature (BBQ Sexual orientation, ChatGPT)",
      x = "Sample size", y = NULL, colour = "Temperature"
    ) +
    theme_minimal(base_size = 12)

  path = file.path(PATHS$figures, outfile)
  ggsave(path, p, width = width, height = height, dpi = dpi)
  message("Wrote ", path)
  invisible(path)
}
