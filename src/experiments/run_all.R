#!/usr/bin/env Rscript
# =============================================================================
# run_all.R — Run every experiment (A -> E) in order.
#
# Each experiment is cached and resumable, so this is safe to interrupt and
# re-run. It makes the full set of real API calls (order ~24k across both
# models); run the offline tests and the small-sample checks first.
#
#   Rscript src/experiments/run_all.R
# =============================================================================

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
        "tables in report/tables/, figures in report/figures/.")
