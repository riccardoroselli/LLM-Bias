# =============================================================================
# test-parse.R — Response parsing (binary 0/1 and BBQ ans0/1/2).
# Confirms clean parses succeed, messy prose is rejected (-> NA, later dropped),
# and mild wrapping (whitespace, quotes, trailing period) is tolerated.
# =============================================================================

if (!exists("parse_binary")) {
  .root <- getwd()
  while (!file.exists(file.path(.root, "CLAUDE.md"))) {
    .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
  }
  source(file.path(.root, "src", "load_all.R"))
}

library(testthat)

test_that("parse_binary accepts clean and mildly-wrapped 0/1", {
  expect_identical(parse_binary("0"),    0L)
  expect_identical(parse_binary("1"),    1L)
  expect_identical(parse_binary(" 0 "),  0L)
  expect_identical(parse_binary("1\n"),  1L)
  expect_identical(parse_binary("0."),   0L)
  expect_identical(parse_binary("'1'"),  1L)
  expect_identical(parse_binary("\"0\""), 0L)
})

test_that("parse_binary rejects ambiguous / prose responses (-> NA)", {
  expect_identical(parse_binary("I choose 0"),        NA_integer_)  # prose, dropped
  expect_identical(parse_binary("The first sentence"), NA_integer_)
  expect_identical(parse_binary("2"),                  NA_integer_) # out of range
  expect_identical(parse_binary("01"),                 NA_integer_) # ambiguous
  expect_identical(parse_binary(""),                   NA_integer_)
  expect_identical(parse_binary(NA),                   NA_integer_)
  expect_identical(parse_binary(NULL),                 NA_integer_)
})

test_that("parse_bbq accepts ans0/ans1/ans2 (any case) and bare digits", {
  expect_identical(parse_bbq("ans0"),  0L)
  expect_identical(parse_bbq("ANS1"),  1L)
  expect_identical(parse_bbq(" ans2 "), 2L)
  expect_identical(parse_bbq("Ans2."), 2L)
  expect_identical(parse_bbq("2"),     2L)   # dropped "ans" prefix
  expect_identical(parse_bbq("0"),     0L)
})

test_that("parse_bbq rejects prose / out-of-range (-> NA)", {
  expect_identical(parse_bbq("ans3"),                 NA_integer_)
  expect_identical(parse_bbq("cannot be determined"), NA_integer_)
  expect_identical(parse_bbq("3"),                    NA_integer_)
  expect_identical(parse_bbq(NA),                     NA_integer_)
})

test_that("vectorised parsers preserve order and NA positions", {
  expect_identical(parse_binary_vec(c("0", "x", "1")), c(0L, NA, 1L))
  expect_identical(parse_bbq_vec(c("ans1", "nope", "ans0")), c(1L, NA, 0L))
})
