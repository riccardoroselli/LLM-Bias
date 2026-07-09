######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# run_tests.R — harness for the offline correctness suite.
# Loads the library, then runs every testthat file in tests/testthat/ (the checks
# that pin our statistics, loaders and BBQ resolver to the paper's published
# values). Makes no API calls and needs no keys. Run from the project root.
######################################

source("src/load_all.R")
library(testthat)

testdir = file.path("src", "tests", "testthat")
cat("Running tests in:", testdir, "\n\n")

# env = globalenv() so the test files can see the functions we just sourced.
test_dir(
  testdir,
  env            = globalenv(),
  stop_on_failure = TRUE,
  reporter       = "summary"
)
cat("\nAll tests passed.\n")
