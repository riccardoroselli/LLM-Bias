######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# test-bbq-resolver.R — offline correctness suite (BBQ 3-way -> binary).
# The reduction matches Table 4 sample sizes, resolves every item but the 4
# degenerate Gender ones (7839 total), and gives each a valid {stereo, anti,
# unknown} triple. The most delicate, un-referenced part, so tested hard.
######################################

# Load the library if it isn't already (run from the project root).
if (!exists("load_bbq")) source("src/load_all.R")
library(testthat)

# Ambiguous+negative counts = the paper's Table 4 sample sizes (all 9 exact).
PAPER_BBQ_N = c(
  "Age" = 920, "Disability" = 389, "Gender" = 1418, "Nationality" = 770,
  "Physical appearance" = 394, "Race" = 1720, "Religion" = 300,
  "Sexual orientation" = 216, "Socioeconomic" = 1716
)
# Rows after resolution: identical except Gender loses its 4 degenerate items.
RESOLVED_N = PAPER_BBQ_N; RESOLVED_N["Gender"] = 1414

test_that("BBQ ambiguous+negative counts match Table 4 exactly", {
  for (cat in names(PAPER_BBQ_N)) {
    expect_equal(bbq_ambig_neg_count(cat), as.integer(PAPER_BBQ_N[[cat]]),
                 info = paste("ambig+neg count for", cat))
  }
})

test_that("Resolver resolves every item except the 4 degenerate Gender ones", {
  total = 0L
  for (cat in names(RESOLVED_N)) {
    d = load_bbq(cat)
    expect_equal(nrow(d), as.integer(RESOLVED_N[[cat]]),
                 info = paste("resolved rows for", cat))
    total = total + nrow(d)
  }
  expect_equal(total, 7839L)   # 7843 ambig+neg - 4 degenerate
})

test_that("Every resolved item has a valid {stereo, anti, unknown} permutation", {
  d = load_bbq("Sexual orientation")
  # The three indices are 0/1/2 in some order, all distinct, for every row.
  idx = cbind(d$stereo_idx, d$anti_idx, d$unknown_idx)
  expect_true(all(idx >= 0L & idx <= 2L))
  expect_true(all(apply(idx, 1L, function(r) length(unique(r)) == 3L)))
  # The unknown_idx really points at the neutral option text.
  neutral_txt = vapply(seq_len(nrow(d)), function(i) {
    d[i, paste0("ans", d$unknown_idx[i])]
  }, character(1))
  expect_true(all(grepl("determin|answer|known|enough|info|cannot|unclear|not sure",
                        neutral_txt, ignore.case = TRUE)))
})

test_that("Prompt assembly includes context, question, and all three options", {
  d = load_bbq("Sexual orientation")
  p = d$prompt[1]
  expect_true(grepl("Context: ",  p, fixed = TRUE))
  expect_true(grepl("Question: ",  p, fixed = TRUE))
  expect_true(grepl("ans0: ", p, fixed = TRUE))
  expect_true(grepl("ans2: ", p, fixed = TRUE))
})
