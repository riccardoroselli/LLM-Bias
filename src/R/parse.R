######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# parse.R — turn a raw LLM response into a clean choice, or NA.
# Following the paper's notebook, we keep a response only if it unambiguously
# encodes one choice; anything else -> NA, later dropped from n.
######################################

# Strip surrounding whitespace and punctuation/quotes (but not interior chars).
strip_edges = function(s) gsub("^[^0-9A-Za-z]+|[^0-9A-Za-z]+$", "", trimws(s))

# Binary datasets (CrowS-Pairs, Winogender): expect "0" or "1", else NA.
# 0 = model preferred the first sentence, 1 = the second.
parse_binary = function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_integer_)
  s = strip_edges(as.character(x))
  if (s %in% c("0", "1")) as.integer(s) else NA_integer_
}

# BBQ: expect "ans0"/"ans1"/"ans2" (any case); fall back to a bare 0/1/2 if the
# model dropped the "ans" prefix. Returns the chosen index 0/1/2, or NA.
parse_bbq = function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_integer_)
  s = tolower(trimws(as.character(x)))
  m = regmatches(s, regexpr("ans[012]", s))
  if (length(m) == 1L) return(as.integer(substr(m, 4L, 4L)))
  s2 = strip_edges(s)
  if (s2 %in% c("0", "1", "2")) return(as.integer(s2))
  NA_integer_
}

# Vectorised over a column of responses.
parse_binary_vec = function(x) vapply(x, parse_binary, integer(1), USE.NAMES = FALSE)
parse_bbq_vec    = function(x) vapply(x, parse_bbq,    integer(1), USE.NAMES = FALSE)
