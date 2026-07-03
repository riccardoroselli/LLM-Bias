#!/usr/bin/env Rscript
# =============================================================================
# run_tests.R — Offline test runner. Makes NO API calls and costs nothing.
#
# Run it either way:
#   * Terminal:  Rscript src/tests/run_tests.R
#   * RStudio:   set working dir inside the project, then source this file.
#
# It sources all modules, then runs every testthat file in tests/testthat/.
# Requires: testthat (all tests); jsonlite (the data-count tests only).
# =============================================================================

# --- bootstrap: locate project root and load all modules ---
.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root)
  if (identical(.p, .root)) stop("Run this from inside the project directory.")
  .root <- .p
}
source(file.path(.root, "src", "load_all.R"))

if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("Package 'testthat' is required to run the tests. Install it with ",
       "install.packages('testthat').")
}

testdir <- file.path(.root, "src", "tests", "testthat")
cat("Running tests in:", testdir, "\n\n")

# env = globalenv() so the test files can see the functions we just sourced.
testthat::test_dir(
  testdir,
  env            = globalenv(),
  stop_on_failure = TRUE,
  reporter       = "summary"
)
cat("\nAll tests passed.\n")
