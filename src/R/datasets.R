# =============================================================================
# datasets.R — Dataset loaders: CrowS-Pairs, BBQ, Winogender.
#   Sections:  [1] CrowS-Pairs   [2] BBQ (+ 3-way->binary resolver)   [3] Winogender
#
# --- SECTION 1: CrowS-Pairs ---------------------------------------------------
# load_crows(): Load a CrowS-Pairs file into binary-choice items.
#
# The file is tab-separated with columns:
#   ""(row index), sent_more, sent_less, stereo_antistereo, bias_type
#
# Reproduction rules (matching the authors' notebook, see ProjectStatus.md):
#   * Sentence #1 = sent_more, sentence #2 = sent_less. The `stereo_antistereo`
#     flag is IGNORED: sent_more is always treated as the "stereotypical" option.
#     (Kept as a column for transparency / possible future analysis.)
#   * Rows whose bias_type is not one of the paper's nine categories (i.e.
#     `autre`) are dropped.
#   * Rows where either sentence is missing/non-text are dropped.
#
# Returns a data.frame with one row per usable pair:
#   dataset, lang, id, category, s1, s2, stereo_antistereo, prompt
# The `prompt` is exactly what will be sent to the model (build_prompt_binary).
# =============================================================================

# lang: "EN" or "FR" (keys of CROWS_FILES in config.R).
load_crows <- function(lang = c("EN", "FR")) {
  lang <- match.arg(lang)
  path <- CROWS_FILES[[lang]]
  if (!file.exists(path)) stop("CrowS-Pairs file not found: ", path)

  df <- utils::read.delim(
    path,
    sep          = "\t",
    quote        = "",           # sentences contain quotes; do not treat as delimiters
    comment.char = "",
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )

  # Keep only the columns we need; guard against missing/whitespace sentences.
  keep <- !is.na(df$sent_more) & !is.na(df$sent_less) &
          nzchar(trimws(df$sent_more)) & nzchar(trimws(df$sent_less))
  df <- df[keep, , drop = FALSE]

  # Map bias_type -> canonical category; drop rows outside the nine categories.
  category <- unname(CROWS_CAT_MAP[df$bias_type])
  in_scope <- !is.na(category)
  df       <- df[in_scope, , drop = FALSE]
  category <- category[in_scope]

  s1 <- df$sent_more   # sentence #1 = "stereotypical" (per reproduction rule)
  s2 <- df$sent_less   # sentence #2 = "anti-stereotypical"

  out <- data.frame(
    dataset           = paste0("crows_", tolower(lang)),
    lang              = lang,
    id                = paste0("crows_", tolower(lang), "_", seq_len(nrow(df))),
    category          = category,
    s1                = s1,
    s2                = s2,
    stereo_antistereo = df$stereo_antistereo,
    stringsAsFactors  = FALSE
  )
  out$prompt <- build_prompt_binary(out$s1, out$s2)

  # Stable ordering by canonical category then original order.
  out <- out[order(match(out$category, CATEGORIES), seq_len(nrow(out))), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Convenience: per-category counts (used by tests and reporting).
crows_category_counts <- function(lang = c("EN", "FR")) {
  d <- load_crows(lang)
  table(factor(d$category, levels = CATEGORIES))
}
# =============================================================================
# --- SECTION 2: BBQ -----------------------------------------------------------
# load_bbq(): Load BBQ items and turn each into a binary stereo/anti choice.
#
# BBQ is 3-way multiple choice (ans0/ans1/ans2), where one option is a neutral
# "unknown" answer. The paper uses only the NEGATIVE questions under the
# AMBIGUOUS context, but gives no code for reducing the 3-way answer to the
# binary stereotypical-vs-anti framework. This module implements (and documents)
# that reduction. There is no reference implementation to check against — this is
# our own design (validated to resolve 7839/7843 items cleanly).
#
# Reduction rules:
#   * Keep items with context_condition == "ambig" AND question_polarity=="neg".
#   * Of the three options, one has group-label "unknown" (the neutral choice).
#   * Among the two NAMED options, the "stereotypical" one is the option whose
#     demographic group appears in additional_metadata$stereotyped_groups. The
#     other named option is the "anti-stereotypical" one.
#   * The model's answer is later scored X=1 iff it chose the stereotypical
#     option; choosing the anti-stereotypical option OR "unknown" counts as X=0.
#
# Matching the stereotyped group to an option is not trivial because the
# `stereotyped_groups` vocabulary and the `answer_info` label vocabulary differ
# per category (e.g. "F" vs "woman", "low SES" vs "lowSES", "Black" vs
# "F-Black", "British" region-label vs name). We normalise both sides, split
# hyphen/underscore compound labels into components, add F<->woman/girl and
# M<->man/boy aliases, and match on the LABEL first, falling back to the answer
# TEXT (needed for Nationality, whose labels are regions not nationalities).
#
# The 4 items that do not resolve (degenerate Gender items where both named
# options are the same gender, e.g. "boy" vs "man") are DROPPED. This makes
# Gender BBQ n = 1414 vs the paper's 1418 — a documented, negligible deviation.
#
# load_bbq(category) returns a data.frame with one row per resolved item:
#   dataset, category, example_id, question_index, context, question,
#   ans0, ans1, ans2, stereo_idx, anti_idx, unknown_idx, id, prompt
# where *_idx are 0-based option indices (0/1/2).
# =============================================================================

# Normalise a string to lowercase alphanumerics only ("low SES" -> "lowses").
.bbq_norm <- function(s) gsub("[^a-z0-9]", "", tolower(s))

# Candidate match keys for one raw string: the normalised whole plus each
# hyphen/underscore component ("F-Black" -> {"fblack","f","black"}).
.bbq_keyset <- function(raw) {
  parts <- unlist(strsplit(gsub("_", "-", raw), "-", fixed = TRUE))
  ks <- unique(c(.bbq_norm(raw), vapply(parts, .bbq_norm, character(1))))
  ks[nzchar(ks)]
}

# Normalised key set for the stereotyped_groups list, with gender aliases.
.bbq_stereo_keys <- function(groups) {
  ks <- unique(unlist(lapply(groups, .bbq_keyset), use.names = FALSE))
  if ("f" %in% ks) ks <- union(ks, c("woman", "girl", "female"))
  if ("m" %in% ks) ks <- union(ks, c("man", "boy", "male"))
  ks
}

# Resolve one parsed BBQ item into 0-based {stereo, anti, unknown} option
# indices, or NULL if it cannot be resolved cleanly.
.bbq_resolve <- function(item) {
  ai <- item$answer_info                 # named list: ans0/ans1/ans2 -> c(text, label)
  ans_names <- c("ans0", "ans1", "ans2")
  labels <- vapply(ans_names, function(a) ai[[a]][2], character(1))
  texts  <- vapply(ans_names, function(a) ai[[a]][1], character(1))

  unknown_pos <- which(labels == "unknown")
  named_pos   <- which(labels != "unknown")
  if (length(unknown_pos) != 1L || length(named_pos) != 2L) return(NULL)

  sg <- .bbq_stereo_keys(item$additional_metadata$stereotyped_groups)

  # Cascade: match on label, then text, then both. Accept the first mode that
  # yields exactly ONE stereotypical option among the two named options.
  for (mode in c("label", "text", "both")) {
    hits <- vapply(named_pos, function(pos) {
      ks <- switch(mode,
        label = .bbq_keyset(labels[pos]),
        text  = .bbq_keyset(texts[pos]),
        both  = union(.bbq_keyset(labels[pos]), .bbq_keyset(texts[pos])))
      length(intersect(ks, sg)) > 0L
    }, logical(1))
    if (sum(hits) == 1L) {
      stereo_pos <- named_pos[hits]
      anti_pos   <- named_pos[!hits]
      return(list(
        stereo_idx  = stereo_pos  - 1L,
        anti_idx    = anti_pos    - 1L,
        unknown_idx = unknown_pos - 1L
      ))
    }
  }
  NULL   # unresolved (the 4 degenerate Gender items) -> caller drops it
}

# Read all ambiguous+negative items of one category as a list of parsed objects.
.bbq_read_ambig_neg <- function(category) {
  stem <- names(BBQ_CAT_MAP)[match(category, BBQ_CAT_MAP)]
  if (is.na(stem)) stop("Unknown BBQ category: '", category, "'")
  path <- file.path(PATHS$bbq, paste0(stem, ".jsonl"))
  if (!file.exists(path)) stop("BBQ file not found: ", path)

  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  # Fast literal prefilter before the (relatively slow) JSON parse. The quoted
  # tokens "ambig" / "neg" match ONLY the exact field values: `"disambig"` and
  # `"nonneg"` do not contain the substrings `"ambig"` / `"neg"` (the opening
  # quote differs). The precise field check below is still authoritative.
  cand <- lines[grepl('"ambig"', lines, fixed = TRUE) &
                grepl('"neg"',   lines, fixed = TRUE)]
  items <- vector("list", length(cand))
  m <- 0L
  for (ln in cand) {
    if (!nzchar(trimws(ln))) next
    item <- jsonlite::fromJSON(ln, simplifyVector = TRUE)
    if (!identical(item$context_condition, "ambig")) next
    if (!identical(item$question_polarity, "neg"))  next
    m <- m + 1L
    items[[m]] <- item
  }
  length(items) <- m
  items
}

.cat_slug <- function(category) gsub("[^a-z0-9]", "", tolower(category))

# Public loader: resolved binary-choice items for one canonical category.
load_bbq <- function(category) {
  items <- .bbq_read_ambig_neg(category)
  keep_items <- list(); keep_res <- list()
  for (it in items) {
    res <- .bbq_resolve(it)
    if (is.null(res)) next
    keep_items[[length(keep_items) + 1L]] <- it
    keep_res[[length(keep_res) + 1L]]     <- res
  }
  n <- length(keep_items)
  if (n == 0L) return(data.frame())

  gs <- function(f) vapply(keep_items, f, character(1))
  gi <- function(f) vapply(keep_res,   f, integer(1))

  out <- data.frame(
    dataset        = "bbq",
    category       = category,
    example_id     = vapply(keep_items, function(x) as.character(x$example_id), character(1)),
    question_index = vapply(keep_items, function(x) as.character(x$question_index), character(1)),
    context        = gs(function(x) x$context),
    question       = gs(function(x) x$question),
    ans0           = gs(function(x) x$ans0),
    ans1           = gs(function(x) x$ans1),
    ans2           = gs(function(x) x$ans2),
    stereo_idx     = gi(function(x) x$stereo_idx),
    anti_idx       = gi(function(x) x$anti_idx),
    unknown_idx    = gi(function(x) x$unknown_idx),
    stringsAsFactors = FALSE
  )
  out$id     <- sprintf("bbq_%s_%04d", .cat_slug(category), seq_len(n))
  out$prompt <- build_prompt_bbq(out$context, out$question, out$ans0, out$ans1, out$ans2)
  rownames(out) <- NULL
  out
}

# Count ambiguous+negative items BEFORE resolution (matches the paper's n in
# Table 4). Used by the data-count test to separate "how many questions exist"
# from "how many we could resolve".
bbq_ambig_neg_count <- function(category) length(.bbq_read_ambig_neg(category))
# =============================================================================
# --- SECTION 3: Winogender ----------------------------------------------------
# load_winogender(): Build Winogender gender-bias binary-choice pairs.
#
# all_sentences.tsv has 720 rows: for every (occupation, other-participant,
# answer-template) combination there are three pronoun variants — male, female,
# neutral. Following the authors' notebook we:
#   * drop the neutral-pronoun sentences,
#   * pair the male-pronoun sentence (#1) with the female-pronoun sentence (#2)
#     of the SAME template,
#   * treat the male sentence as the "stereotypical" option (this is the paper's
#     convention; it does NOT use the BLS occupation gender statistics).
# This yields n = 240 pairs (60 occupations x 2 participant forms x 2 templates).
#
# We pair by the shared sentence-id stem (everything before ".male/.female.txt")
# rather than by row position, so the pairing is correct regardless of file order.
#
# Returns a data.frame: dataset, category, id, stem, s1, s2, prompt.
# =============================================================================

load_winogender <- function() {
  path <- file.path(PATHS$winogender, "all_sentences.tsv")
  if (!file.exists(path)) stop("Winogender file not found: ", path)

  df <- utils::read.delim(
    path, sep = "\t", quote = "", comment.char = "",
    stringsAsFactors = FALSE, fileEncoding = "UTF-8"
  )
  # Expected columns: sentid, sentence.
  stem_of <- function(s) sub("\\.(male|female|neutral)\\.txt$", "", s)

  male   <- df[grepl("\\.male\\.txt$",   df$sentid), , drop = FALSE]
  female <- df[grepl("\\.female\\.txt$", df$sentid), , drop = FALSE]
  male$stem   <- stem_of(male$sentid)
  female$stem <- stem_of(female$sentid)

  merged <- merge(
    male[,   c("stem", "sentence")],
    female[, c("stem", "sentence")],
    by = "stem", suffixes = c("_male", "_female")
  )
  merged <- merged[order(merged$stem), , drop = FALSE]

  out <- data.frame(
    dataset  = "winogender",
    category = "Gender",
    id       = paste0("winogender_", seq_len(nrow(merged))),
    stem     = merged$stem,
    s1       = merged$sentence_male,    # male sentence = #1 ("stereotypical")
    s2       = merged$sentence_female,  # female sentence = #2
    stringsAsFactors = FALSE
  )
  out$prompt <- build_prompt_binary(out$s1, out$s2)
  rownames(out) <- NULL
  out
}
