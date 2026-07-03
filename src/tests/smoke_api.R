#!/usr/bin/env Rscript
# =============================================================================
# smoke_api.R — Minimal live-API smoke test (COSTS A FEW CENTS).
#
# Verifies, for BOTH models, that: (1) the .env key is read, (2) a real call
# succeeds, (3) the binary parser handles the response, (4) the response is
# written to the cache, and (5) a second run is served entirely from cache
# (no new calls). Run this once before launching the full experiments.
#
#   Rscript src/tests/smoke_api.R
# =============================================================================

.root <- normalizePath(getwd(), mustWork = FALSE)
while (!file.exists(file.path(.root, "CLAUDE.md"))) {
  .p <- dirname(.root); if (identical(.p, .root)) stop("Run inside the project"); .root <- .p
}
source(file.path(.root, "src", "load_all.R"))

# Two tiny binary-choice prompts (obvious answers, just to exercise the path).
items <- data.frame(
  id      = c("smoke_1", "smoke_2"),
  dataset = "smoke",
  prompt  = c(
    build_prompt_binary("The sky is blue.", "The sky is green."),
    build_prompt_binary("Water is wet.",    "Fire is wet.")
  ),
  stringsAsFactors = FALSE
)

for (mk in names(MODELS)) {
  cat("\n=====================", MODELS[[mk]]$label, "=====================\n")

  cat("-- First run (expect real API calls) --\n")
  r1 <- run_dataset(items, mk, temperature = DEFAULT_TEMPERATURE,
                    dataset_name = "smoke", parse_fun = parse_binary,
                    progress_every = 1L)
  print(r1[, c("id", "raw_response", "parsed", "from_cache")])
  m1 <- attr(r1, "run_meta")
  cat(sprintf("   new calls: %d, cache hits: %d, parsed ok: %d/%d\n",
              m1$new_calls, m1$cache_hits, m1$n_parsed, m1$n))

  cat("-- Second run (expect 100%% cache hits, 0 new calls) --\n")
  r2 <- run_dataset(items, mk, temperature = DEFAULT_TEMPERATURE,
                    dataset_name = "smoke", parse_fun = parse_binary,
                    progress_every = 1L)
  m2 <- attr(r2, "run_meta")
  cat(sprintf("   new calls: %d (should be 0), cache hits: %d\n",
              m2$new_calls, m2$cache_hits))
  if (m2$new_calls != 0L) {
    cat("   WARNING: caching/resume did not work — investigate before full runs.\n")
  } else {
    cat("   OK: cache + resume working.\n")
  }
}

cat("\nSmoke test complete. Cache files written under data/cache/ (smoke__*.jsonl).\n")
cat("You can delete those smoke files; they do not affect the experiments.\n")
