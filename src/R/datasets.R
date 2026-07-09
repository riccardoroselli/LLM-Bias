######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# datasets.R — dataset loaders: CrowS-Pairs, BBQ, Winogender.
# Sections:  [1] CrowS-Pairs   [2] BBQ (+ 3-way -> binary resolver)   [3] Winogender
# Each loader returns a data.frame with at least `id`, `category`, `prompt`.
######################################

#### Section 1: CrowS-Pairs ####
# Tab-separated: ""(row index), sent_more, sent_less, stereo_antistereo, bias_type.
# Reproduction rules (from the notebook): sentence #1 = sent_more, #2 = sent_less,
# and sent_more is always the "stereotypical" one -- the stereo_antistereo flag is
# ignored (kept only for transparency). Rows outside the nine categories (`autre`)
# or with a missing sentence are dropped.

# lang: "EN" or "FR" (keys of CROWS_FILES in config.R).
load_crows = function(lang = c("EN", "FR")) {
  path = CROWS_FILES[[lang]]
  if (!file.exists(path)) stop("CrowS-Pairs file not found: ", path)

  df = utils::read.delim(
    path,
    sep          = "\t",
    quote        = "",           # sentences contain quotes; do not treat as delimiters
    comment.char = "",
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )

  # Drop missing/blank sentences.
  keep = !is.na(df$sent_more) & !is.na(df$sent_less) &
         nzchar(trimws(df$sent_more)) & nzchar(trimws(df$sent_less))
  df = df[keep, , drop = FALSE]

  # Map to canonical category; drop rows outside the nine.
  category = unname(CROWS_CAT_MAP[df$bias_type])
  in_scope = !is.na(category)
  df       = df[in_scope, , drop = FALSE]
  category = category[in_scope]

  s1 = df$sent_more   # sentence #1 = "stereotypical" (per reproduction rule)
  s2 = df$sent_less   # sentence #2 = "anti-stereotypical"

  out = data.frame(
    dataset           = paste0("crows_", tolower(lang)),
    lang              = lang,
    id                = paste0("crows_", tolower(lang), "_", seq_len(nrow(df))),
    category          = category,
    s1                = s1,
    s2                = s2,
    stereo_antistereo = df$stereo_antistereo,
    stringsAsFactors  = FALSE
  )
  out$prompt = build_prompt_binary(out$s1, out$s2)

  # Stable ordering by canonical category, then original order.
  out = out[order(match(out$category, CATEGORIES), seq_len(nrow(out))), , drop = FALSE]
  rownames(out) = NULL
  out
}

# Per-category counts (used by tests and reporting).
crows_category_counts = function(lang = c("EN", "FR")) {
  d = load_crows(lang)
  table(factor(d$category, levels = CATEGORIES))
}

#### Section 2: BBQ (+ 3-way -> binary resolver) ####
# BBQ is 3-way (ans0/ans1/ans2) with one neutral "unknown" option. The paper uses
# only ambiguous+negative questions but gives no code for reducing the 3-way answer
# to stereo-vs-anti; this reduction is our own design (resolves 7839/7843 items).
#
# Reduction rules:
#   * Keep context_condition == "ambig" AND question_polarity == "neg".
#   * One option is labelled "unknown" (neutral).
#   * Of the two named options, the "stereotypical" one is whose group is in
#     additional_metadata$stereotyped_groups; the other is "anti".
#   * Scored later X=1 iff the model picks the stereotypical option (anti or
#     unknown -> X=0).
#
# Matching group->option is tricky: the stereotyped_groups and answer_info label
# vocabularies differ per category ("F" vs "woman", "low SES" vs "lowSES", "Black"
# vs "F-Black"). So we normalise both, split compound labels, add F<->woman/girl
# and M<->man/boy aliases, and match on label first, then answer text (needed for
# Nationality, whose labels are regions).
#
# The 4 unresolved items (degenerate Gender, both named options same gender) are
# dropped -> Gender n = 1414 vs paper 1418 (documented, negligible).

# Normalise a string to lowercase alphanumerics only ("low SES" -> "lowses").
bbq_norm = function(s) gsub("[^a-z0-9]", "", tolower(s))

# Match keys for a raw string: the normalised whole plus each hyphen/underscore
# component ("F-Black" -> {"fblack","f","black"}).
bbq_keyset = function(raw) {
  parts = unlist(strsplit(gsub("_", "-", raw), "-", fixed = TRUE))
  ks = unique(c(bbq_norm(raw), vapply(parts, bbq_norm, character(1))))
  ks[nzchar(ks)]
}

# Normalised key set for the stereotyped_groups list, with gender aliases.
bbq_stereo_keys = function(groups) {
  ks = unique(unlist(lapply(groups, bbq_keyset), use.names = FALSE))
  if ("f" %in% ks) ks = union(ks, c("woman", "girl", "female"))
  if ("m" %in% ks) ks = union(ks, c("man", "boy", "male"))
  ks
}

# Resolve one item into 0-based {stereo, anti, unknown} indices, or NULL.
bbq_resolve = function(item) {
  ai = item$answer_info                  # named list: ans0/ans1/ans2 -> c(text, label)
  ans_names = c("ans0", "ans1", "ans2")
  labels = vapply(ans_names, function(a) ai[[a]][2], character(1))
  texts  = vapply(ans_names, function(a) ai[[a]][1], character(1))

  unknown_pos = which(labels == "unknown")
  named_pos   = which(labels != "unknown")
  if (length(unknown_pos) != 1L || length(named_pos) != 2L) return(NULL)

  sg = bbq_stereo_keys(item$additional_metadata$stereotyped_groups)

  # Try label, then text, then both; accept the first that flags exactly ONE of
  # the two named options as stereotypical.
  for (mode in c("label", "text", "both")) {
    hits = vapply(named_pos, function(pos) {
      ks = switch(mode,
        label = bbq_keyset(labels[pos]),
        text  = bbq_keyset(texts[pos]),
        both  = union(bbq_keyset(labels[pos]), bbq_keyset(texts[pos])))
      length(intersect(ks, sg)) > 0L
    }, logical(1))
    if (sum(hits) == 1L) {
      stereo_pos = named_pos[hits]
      anti_pos   = named_pos[!hits]
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
bbq_read_ambig_neg = function(category) {
  stem = names(BBQ_CAT_MAP)[match(category, BBQ_CAT_MAP)]
  if (is.na(stem)) stop("Unknown BBQ category: '", category, "'")
  path = file.path(PATHS$bbq, paste0(stem, ".jsonl"))
  if (!file.exists(path)) stop("BBQ file not found: ", path)

  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  # Fast literal prefilter before the slower JSON parse. The quoted "ambig"/"neg"
  # match only the exact field values ("disambig"/"nonneg" don't contain them --
  # the opening quote differs). The field check below is still authoritative.
  cand = lines[grepl('"ambig"', lines, fixed = TRUE) &
               grepl('"neg"',   lines, fixed = TRUE)]
  items = vector("list", length(cand))
  m = 0L
  for (ln in cand) {
    if (!nzchar(trimws(ln))) next
    item = jsonlite::fromJSON(ln, simplifyVector = TRUE)
    if (!identical(item$context_condition, "ambig")) next
    if (!identical(item$question_polarity, "neg"))  next
    m = m + 1L
    items[[m]] = item
  }
  length(items) = m
  items
}

# Public loader: resolved binary-choice items for one category, one row each.
# *_idx columns are 0-based option indices (0/1/2).
load_bbq = function(category) {
  items = bbq_read_ambig_neg(category)
  keep_items = list(); keep_res = list()
  for (it in items) {
    res = bbq_resolve(it)
    if (is.null(res)) next
    keep_items[[length(keep_items) + 1L]] = it
    keep_res[[length(keep_res) + 1L]]     = res
  }
  n = length(keep_items)
  if (n == 0L) return(data.frame())

  gs = function(f) vapply(keep_items, f, character(1))
  gi = function(f) vapply(keep_res,   f, integer(1))

  out = data.frame(
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
  out$id     = sprintf("bbq_%s_%04d", bbq_norm(category), seq_len(n))
  out$prompt = build_prompt_bbq(out$context, out$question, out$ans0, out$ans1, out$ans2)
  rownames(out) = NULL
  out
}

# Count ambiguous+negative items BEFORE resolution (= paper's Table 4 n). Lets the
# test separate "how many exist" from "how many we resolved".
bbq_ambig_neg_count = function(category) length(bbq_read_ambig_neg(category))

#### Section 3: Winogender ####
# all_sentences.tsv has 720 rows: each template has 3 pronoun variants (male,
# female, neutral). Following the notebook: drop neutral, pair male (#1) with
# female (#2) of the same template, and treat male as "stereotypical" (paper's
# convention -- the BLS occupation stats are NOT used). Gives n = 240 pairs.
# We pair by the shared sentence-id stem, not row position, so file order is safe.
load_winogender = function() {
  path = file.path(PATHS$winogender, "all_sentences.tsv")
  if (!file.exists(path)) stop("Winogender file not found: ", path)

  df = utils::read.delim(
    path, sep = "\t", quote = "", comment.char = "",
    stringsAsFactors = FALSE, fileEncoding = "UTF-8"
  )
  # Expected columns: sentid, sentence.
  stem_of = function(s) sub("\\.(male|female|neutral)\\.txt$", "", s)

  male   = df[grepl("\\.male\\.txt$",   df$sentid), , drop = FALSE]
  female = df[grepl("\\.female\\.txt$", df$sentid), , drop = FALSE]
  male$stem   = stem_of(male$sentid)
  female$stem = stem_of(female$sentid)

  merged = merge(
    male[,   c("stem", "sentence")],
    female[, c("stem", "sentence")],
    by = "stem", suffixes = c("_male", "_female")
  )
  merged = merged[order(merged$stem), , drop = FALSE]

  out = data.frame(
    dataset  = "winogender",
    category = "Gender",
    id       = paste0("winogender_", seq_len(nrow(merged))),
    stem     = merged$stem,
    s1       = merged$sentence_male,    # male sentence = #1 ("stereotypical")
    s2       = merged$sentence_female,  # female sentence = #2
    stringsAsFactors = FALSE
  )
  out$prompt = build_prompt_binary(out$s1, out$s2)
  rownames(out) = NULL
  out
}
