#!/usr/bin/env Rscript
# =============================================================================
# run_tests.R — Harness for the offline correctness suite.
#
# Loads the library, then runs every testthat file in tests/testthat/ (the
# checks that pin our statistics, loaders and BBQ resolver to the paper's
# published values). Makes no API calls and needs no keys, so it re-verifies the
# delivered code for free. Requires: testthat (all tests); jsonlite (data-count
# tests only).
# =============================================================================

# Locate the project root, then load every module so the tests can see them.
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
