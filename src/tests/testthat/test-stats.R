######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# test-stats.R — offline correctness suite (statistics).
# Checks SS / EBT / BF reproduce the paper's own Table 3 values (EN CrowS, ChatGPT),
# cross-checked in Python:
#   Age        n=91,  k=54  -> SS 59.34%, EBT 9.29e-2, BF 6.32e-1
#   Disability n=65,  k=38  -> SS 58.46%, EBT 2.15e-1, BF 3.86e-1
#   Gender     n=320, k=168 -> SS 52.50%, EBT 4.02e-1, BF 1.04e-1
######################################

# Load the library if it isn't already (run from the project root).
if (!exists("bf10")) source("src/load_all.R")

library(testthat)

test_that("Stereotype score matches Table 3 (directional rate)", {
  expect_equal(stereotype_rate(91,  54),  54/91,  tolerance = 1e-9)
  expect_equal(stereotype_rate(65,  38),  38/65,  tolerance = 1e-9)
  expect_equal(stereotype_rate(320, 168), 168/320, tolerance = 1e-9)
  # For these fixtures k/n > 0.5, so SS == rate.
  expect_equal(stereotype_score(91, 54), 54/91, tolerance = 1e-9)
  # SS is symmetric: max{k/n, 1-k/n}.
  expect_equal(stereotype_score(100, 40), 0.60, tolerance = 1e-9)
})

test_that("Exact binomial test reproduces Table 3 p-values", {
  expect_equal(ebt_pvalue(91,  54),  9.2947e-02, tolerance = 1e-4)
  expect_equal(ebt_pvalue(65,  38),  2.1454e-01, tolerance = 1e-4)
  expect_equal(ebt_pvalue(320, 168), 4.0177e-01, tolerance = 1e-4)
  # Perfectly balanced -> p-value 1.
  expect_equal(ebt_pvalue(100, 50), 1, tolerance = 1e-9)
})

test_that("Bayes factor reproduces Table 3 values", {
  expect_equal(bf10(91,  54),  6.3244e-01, tolerance = 1e-3)
  expect_equal(bf10(65,  38),  3.8599e-01, tolerance = 1e-3)
  expect_equal(bf10(320, 168), 1.0416e-01, tolerance = 1e-3)
  # A larger cross-checked case: n=1720, k=884 -> ~0.059.
  expect_equal(bf10(1720, 884), 5.9e-2, tolerance = 2e-3)
})

test_that("BF10 closed form equals 1 / [(n+1) C(n,k) 0.5^n]", {
  for (nk in list(c(10, 6), c(50, 30), c(91, 54), c(320, 168))) {
    n = nk[1]; k = nk[2]
    closed = 1 / ((n + 1) * choose(n, k) * 0.5^n)
    expect_equal(bf10(n, k), closed, tolerance = 1e-9)
  }
})

test_that("log_bf10 stays finite where bf10 overflows", {
  # Extreme evidence like the paper's 1e+117: bf10() may be Inf, log stays finite.
  expect_true(is.finite(log_bf10(1720, 1250)))
  expect_equal(log_bf10(320, 168), log(bf10(320, 168)), tolerance = 1e-9)
})

test_that("BF interpretation matches the Andraszewicz scale (Table 1)", {
  expect_equal(interpret_bf(6.3244e-01), "Anecdotal evidence for H0")  # Age
  expect_equal(interpret_bf(1.0416e-01), "Moderate evidence for H0")   # Gender
  expect_equal(interpret_bf(5.9e-2),     "Strong evidence for H0")     # <1/10
  expect_equal(interpret_bf(255),        "Extreme evidence for H1")    # Race crows
  expect_equal(interpret_bf(11.6),       "Strong evidence for H1")     # Nationality
  expect_equal(interpret_bf(2),          "Anecdotal evidence for H1")
})

test_that("BF strength flags match the paper's bold/underline convention", {
  expect_equal(bf_strength(5.9e-2), "strong")    # < 1/10  -> bold
  expect_equal(bf_strength(1.04e-1), "moderate") # in (1/10, 1/3) -> underline
  expect_equal(bf_strength(6.32e-1), "none")     # (1/3, 1) -> plain
  expect_equal(bf_strength(255),     "strong")   # > 10 -> bold
  expect_equal(bf_strength(7.26),    "moderate") # (3, 10] -> underline
})

test_that("EBT significance stars follow the 0.05 / 0.01 convention", {
  expect_equal(ebt_stars(4.0177e-01), "")    # not significant
  expect_equal(ebt_stars(2.43e-02),   "*")   # < 0.05
  expect_equal(ebt_stars(5.47e-04),   "**")  # < 0.01
})
