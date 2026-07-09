#!/usr/bin/env Rscript
######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# main.R — THE single entry point for the whole project.
#
# Usage:
#   Rscript src/main.R tests     # offline tests only (NO API calls, zero cost)
#   Rscript src/main.R A         # one experiment (A/B/C/D/E)
#   Rscript src/main.R all       # all experiments A..E in order (the full run)
#   Rscript src/main.R           # print usage
#
# Small-sample dry run of any experiment (first N items per model):
#   RUN_LIMIT=10 Rscript src/main.R A
#
# Recommended first time: tests -> RUN_LIMIT=10 main.R A -> all.
# Everything is cached and resumable, so `all` is safe to interrupt and re-run.
######################################

# Run from the project root, e.g. `Rscript src/main.R A`.
run_script = function(rel) source(file.path("src", rel))

args = commandArgs(trailingOnly = TRUE)
cmd  = if (length(args) >= 1L) tolower(args[[1]]) else "help"

switch(cmd,
  tests = run_script("tests/run_tests.R"),
  a     = run_script("experiments/run_A_crows_en.R"),
  b     = run_script("experiments/run_B_crows_fr.R"),
  c     = run_script("experiments/run_C_bbq.R"),
  d     = run_script("experiments/run_D_temperature.R"),
  e     = run_script("experiments/run_E_gender.R"),
  all   = run_script("experiments/run_all.R"),
  {
    cat("Usage: Rscript src/main.R <tests|A|B|C|D|E|all>\n")
    quit(status = 1L)
  }
)
