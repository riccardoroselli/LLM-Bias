# =============================================================================
# collect.R — LLM API client + response cache + collection engine.
#   Sections:  [1] API client   [2] cache   [3] run_dataset (collect w/ caching)
#
# --- SECTION 1: API client ----------------------------------------------------
# call_llm(): A single client for both OpenAI and DeepSeek.
#
# Both providers expose an OpenAI-compatible POST /chat/completions endpoint, so
# one function serves both; only base_url / model / key differ (see MODELS in
# config.R). Uses httr2 with automatic retry + exponential backoff on transient
# errors (HTTP 429 and 5xx), honouring any Retry-After header.
#
# call_llm() returns a list(content, finish_reason, status). On a NON-transient
# HTTP error (e.g. 401 bad key) httr2 raises — the caller (collect.R) decides
# whether that is fatal. The API key is passed in and never logged.
# =============================================================================

call_llm <- function(model_spec, prompt,
                     temperature = DEFAULT_TEMPERATURE,
                     api_key,
                     max_retries = API_MAX_RETRIES,
                     timeout     = API_TIMEOUT_SEC) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("Package 'httr2' is required for API calls. install.packages('httr2').")
  }
  url  <- paste0(model_spec$base_url, "/chat/completions")
  body <- list(
    model       = model_spec$model,
    messages    = list(list(role = "user", content = prompt)),
    temperature = temperature
  )

  req <- httr2::request(url)
  req <- httr2::req_headers(req,
    Authorization  = paste("Bearer", api_key),
    `Content-Type` = "application/json"
  )
  req <- httr2::req_body_json(req, body, auto_unbox = TRUE)
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_retry(req,
    max_tries    = max_retries,
    is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504),
    backoff      = function(i) min(60, 2^i)
  )

  resp   <- httr2::req_perform(req)
  parsed <- httr2::resp_body_json(resp)

  content <- tryCatch(parsed$choices[[1]]$message$content,
                      error = function(e) NA_character_)
  if (is.null(content)) content <- NA_character_

  list(
    content       = content,
    finish_reason = tryCatch(parsed$choices[[1]]$finish_reason,
                             error = function(e) NA_character_),
    status        = httr2::resp_status(resp)
  )
}
# =============================================================================
# --- SECTION 2: cache ---------------------------------------------------------
# Crash-safe, resumable cache of raw API responses.
#
# We run tens of thousands of calls across two models and several temperatures,
# so a crash / rate-limit / interrupt must never mean starting over. The cache
# is an append-only JSONL file per (dataset, model, temperature). Each line is
# one record {key, id, model, temperature, response, ts}. On resume we read the
# file into an in-memory hashmap keyed by the request hash and skip anything
# already present. Append-only + per-line writes make it robust to interruption.
#
# Cached files live under data/cache/ which is gitignored (they are large and
# fully regeneratable, and embed prompt-derived hashes).
# =============================================================================

# Path of the cache file for a given (dataset, model, temperature).
cache_path <- function(dataset, model_id, temperature) {
  if (!dir.exists(PATHS$cache)) dir.create(PATHS$cache, recursive = TRUE, showWarnings = FALSE)
  file.path(PATHS$cache,
            sprintf("%s__%s__t%.1f.jsonl", dataset, model_id, temperature))
}

# Deterministic request hash. Includes provider+model+temperature+prompt so that
# changing any of them produces a new key (and thus a fresh call).
cache_key <- function(model_spec, temperature, prompt) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Package 'digest' is required for the cache. install.packages('digest').")
  }
  payload <- paste(model_spec$provider, model_spec$model,
                   sprintf("%.4f", temperature), prompt, sep = "")
  digest::digest(payload, algo = "sha1")
}

# Load an existing cache file into an environment used as a hashmap key->response.
cache_load <- function(path) {
  env <- new.env(parent = emptyenv())
  if (!file.exists(path)) return(env)
  lines <- readLines(path, warn = FALSE)
  for (ln in lines) {
    if (!nzchar(trimws(ln))) next
    rec <- tryCatch(jsonlite::fromJSON(ln), error = function(e) NULL)
    if (is.null(rec) || is.null(rec$key)) next
    resp <- rec$response
    if (is.null(resp)) resp <- NA_character_
    assign(rec$key, resp, envir = env)
  }
  env
}

# O(1) lookup; returns the cached response string, or NULL if absent.
cache_get <- function(cache_env, key) {
  if (exists(key, envir = cache_env, inherits = FALSE)) {
    get(key, envir = cache_env, inherits = FALSE)
  } else {
    NULL
  }
}

# Append one response record. Opens in append mode and closes immediately so the
# line is flushed to disk even if the process is later killed.
cache_append <- function(path, key, id, response, model_id, temperature) {
  rec <- list(
    key         = key,
    id          = id,
    model       = model_id,
    temperature = temperature,
    response    = response,
    ts          = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  )
  line <- jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null")
  con <- file(path, open = "at", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(line, con)
}
# =============================================================================
# --- SECTION 3: collection engine ---------------------------------------------
# run_dataset(): Run a set of prompts through a model, with caching + resumability.
#
# run_dataset() takes a data.frame of items (must have `id` and `prompt`
# columns), a model key ("chatgpt"/"deepseek"), and a temperature. For each item
# it returns the cached response if present, otherwise calls the API and appends
# the result to the cache. It never re-calls an item already in the cache, so
# re-running after a crash resumes exactly where it left off.
#
# Failures policy (to survive long runs):
#   * A fatal auth error (401/403) stops the whole run — the key is wrong.
#   * Other transient/unknown errors: the item is left UNCACHED (so it is retried
#     on the next run), and the run continues — unless `max_consecutive_failures`
#     is hit, which aborts (something is systematically wrong).
#
# Returns the input data.frame with added columns:
#   raw_response (chr), parsed (int choice index or NA), from_cache (lgl).
# The mapping from `parsed` to the bias indicator X (stereotypical = 1) is done
# later in analysis.R, because it needs dataset-specific knowledge (for BBQ the
# stereotypical option index varies per item).
# =============================================================================

run_dataset <- function(items,
                        model_key,
                        temperature  = DEFAULT_TEMPERATURE,
                        dataset_name = NULL,
                        parse_fun    = parse_binary,
                        limit        = NULL,
                        verbose      = TRUE,
                        progress_every = 50L,
                        max_consecutive_failures = 20L) {
  stopifnot(is.data.frame(items))
  if (!all(c("id", "prompt") %in% names(items))) {
    stop("`items` must have `id` and `prompt` columns.")
  }
  model_spec <- MODELS[[model_key]]
  if (is.null(model_spec)) stop("Unknown model key: '", model_key, "'")
  if (is.null(dataset_name)) {
    dataset_name <- if ("dataset" %in% names(items)) items$dataset[1] else "dataset"
  }
  if (!is.null(limit)) items <- utils::head(items, limit)

  path      <- cache_path(dataset_name, model_key, temperature)
  cache_env <- cache_load(path)
  n <- nrow(items)

  responses  <- rep(NA_character_, n)
  parsed     <- rep(NA_integer_,   n)
  from_cache <- rep(FALSE, n)

  api_key     <- NULL   # fetched lazily on first real call
  consec_fail <- 0L
  n_calls     <- 0L
  n_hits      <- 0L

  for (i in seq_len(n)) {
    prompt <- items$prompt[i]
    key    <- cache_key(model_spec, temperature, prompt)
    cached <- cache_get(cache_env, key)

    if (!is.null(cached) && !is.na(cached)) {
      responses[i]  <- cached
      from_cache[i] <- TRUE
      n_hits        <- n_hits + 1L
    } else {
      if (is.null(api_key)) api_key <- get_api_key(model_spec)
      res <- tryCatch(
        call_llm(model_spec, prompt, temperature, api_key),
        error = function(e) list(content = NA_character_, error = conditionMessage(e))
      )
      if (!is.null(res$error)) {
        if (grepl("401|403|invalid.?api.?key|unauthor", res$error, ignore.case = TRUE)) {
          stop("Fatal API error (check the API key in .env): ", res$error)
        }
        consec_fail <- consec_fail + 1L
        if (consec_fail >= max_consecutive_failures) {
          stop("Aborting after ", consec_fail,
               " consecutive API failures. Last error: ", res$error)
        }
        if (verbose) message(sprintf("  [%d/%d] API failure (%s) — will retry next run",
                                      i, n, res$error))
        # leave responses[i] = NA and UNCACHED so it is retried later
      } else {
        consec_fail  <- 0L
        n_calls      <- n_calls + 1L
        responses[i] <- res$content
        if (!is.na(res$content)) {
          cache_append(path, key, items$id[i], res$content, model_key, temperature)
          assign(key, res$content, envir = cache_env)
        }
        if (API_SLEEP_SEC > 0) Sys.sleep(API_SLEEP_SEC)
      }
    }

    parsed[i] <- parse_fun(responses[i])

    if (verbose && (i %% progress_every == 0L || i == n)) {
      message(sprintf("  [%s | %s | t=%.1f] %d/%d  (cache hits: %d, new calls: %d)",
                      dataset_name, model_key, temperature, i, n, n_hits, n_calls))
    }
  }

  items$raw_response <- responses
  items$parsed       <- parsed
  items$from_cache   <- from_cache
  attr(items, "run_meta") <- list(
    dataset = dataset_name, model = model_key, temperature = temperature,
    n = n, cache_hits = n_hits, new_calls = n_calls,
    n_parsed = sum(!is.na(parsed)), n_unparsed = sum(is.na(parsed))
  )
  items
}
