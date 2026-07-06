#!/usr/bin/env Rscript
# =============================================================================
# run_all.R — Run experiments A -> E in order (the full reproduction).
# Sources each run_*.R in turn. Every experiment is cached and resumable, so
# the whole sequence is safe to interrupt and re-run. Dispatched by main.R as
# `all`.
# =============================================================================

# Locate the project root, then find the experiments directory.
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
}
exp_dir <- file.path(.root, "src", "experiments")

scripts <- c(
  "run_A_crows_en.R",
  "run_B_crows_fr.R",
  "run_C_bbq.R",
  "run_D_temperature.R",
  "run_E_gender.R"
)

for (s in scripts) {
  message("\n############################################################")
  message("# ", s)
  message("############################################################")
  source(file.path(exp_dir, s))
}

message("\nAll experiments complete. Results in data/results/, ",
        "tables in outputs/tables/, figures in outputs/figures/.")
