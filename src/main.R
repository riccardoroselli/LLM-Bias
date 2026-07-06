#!/usr/bin/env Rscript
# =============================================================================
# main.R — THE single entry point for the whole project.
#
# Usage:
#   Rscript src/main.R tests     # offline tests only (NO API calls, zero cost)
#   Rscript src/main.R A         # one experiment (A/B/C/D/E)
#   Rscript src/main.R all       # all experiments A..E in order (the full run)
#   Rscript src/main.R           # show this help
#
# Small-sample dry run of any experiment (first N items per model):
#   RUN_LIMIT=10 Rscript src/main.R A
#
# Recommended order the first time:
#   tests  ->  RUN_LIMIT=10 main.R A  ->  all
# Everything is cached and resumable, so `all` is safe to interrupt and re-run.
# =============================================================================

# Locate the project root (works from anywhere inside the project).
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root)
  if (identical(.p, .root)) stop("Run this from inside the project directory.")
  .root <- .p
}
.src <- file.path(.root, "src")

.run <- function(rel) source(file.path(.src, rel))

.usage <- function() {
  cat(
    "\nLLM-Bias reproduction — single entry point\n",
    "\nUsage: Rscript src/main.R <command>\n\n",
    "  tests   Offline tests (stats, parsers, data counts). No API, no cost.\n",
    "  A       Experiment A  -> Table 3   (English CrowS-Pairs)\n",
    "  B       Experiment B  -> Fig 2     (English vs French CrowS)\n",
    "  C       Experiment C  -> Table 4   (BBQ; the largest run)\n",
    "  D       Experiment D  -> Table 5 + Fig 3 (temperature x sample size)\n",
    "  E       Experiment E  -> Table 6   (gender across three datasets)\n",
    "  all     Experiments A..E in order (the full run)\n\n",
    "Dry run (first N items): RUN_LIMIT=10 Rscript src/main.R A\n",
    "Recommended first-time order: tests -> RUN_LIMIT=10 A -> all\n\n",
    sep = ""
  )
}

args <- commandArgs(trailingOnly = TRUE)
cmd  <- if (length(args) >= 1L) tolower(args[[1]]) else "help"

switch(cmd,
  help  = .usage(),
  tests = .run("tests/run_tests.R"),
  a     = .run("experiments/run_A_crows_en.R"),
  b     = .run("experiments/run_B_crows_fr.R"),
  c     = .run("experiments/run_C_bbq.R"),
  d     = .run("experiments/run_D_temperature.R"),
  e     = .run("experiments/run_E_gender.R"),
  all   = .run("experiments/run_all.R"),
  {
    cat("Unknown command: '", cmd, "'\n", sep = "")
    .usage()
    quit(status = 1L)
  }
)
