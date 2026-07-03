# =============================================================================
# parse.R — Turn a raw LLM text response into a clean choice, or NA.
#
# The models are instructed to answer with just "0"/"1" (binary datasets) or
# "ans0"/"ans1"/"ans2" (BBQ). Real responses are usually clean but occasionally
# wrapped in punctuation or prose. Following the paper's own analysis notebook
# (which kept only responses in {'0','1'} and dropped the rest), we accept a
# response only when it unambiguously encodes a single choice, and return NA
# otherwise. NA responses are later DROPPED from n (they do not count as either
# a stereotypical or anti-stereotypical preference).
# =============================================================================

# Strip surrounding whitespace and punctuation/quotes (but not interior chars).
.strip_edges <- function(s) gsub("^[^0-9A-Za-z]+|[^0-9A-Za-z]+$", "", trimws(s))

# Binary datasets (CrowS-Pairs, Winogender): expect "0" or "1".
# Returns integer 0 or 1, or NA_integer_ if not cleanly parseable.
# 0 = model preferred the FIRST sentence, 1 = the SECOND sentence.
parse_binary <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_integer_)
  s <- .strip_edges(as.character(x))
  if (s %in% c("0", "1")) as.integer(s) else NA_integer_
}

# BBQ: expect "ans0"/"ans1"/"ans2" (case-insensitive). Falls back to a bare
# 0/1/2 if the model dropped the "ans" prefix. Returns 0/1/2 (the chosen option
# index) or NA_integer_.
parse_bbq <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_integer_)
  s <- tolower(trimws(as.character(x)))
  m <- regmatches(s, regexpr("ans[012]", s))
  if (length(m) == 1L) return(as.integer(substr(m, 4L, 4L)))
  s2 <- .strip_edges(s)
  if (s2 %in% c("0", "1", "2")) return(as.integer(s2))
  NA_integer_
}

# Vectorised helpers (convenient when applied to a whole column of responses).
parse_binary_vec <- function(x) vapply(x, parse_binary, integer(1), USE.NAMES = FALSE)
parse_bbq_vec    <- function(x) vapply(x, parse_bbq,    integer(1), USE.NAMES = FALSE)
