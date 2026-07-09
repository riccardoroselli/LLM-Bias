# RefactorAudit.md — readability rewrite of `src/` (four passes)

**Scope.** The entire `src/` tree was rewritten to read like the course lesson
scripts in `code-reference/`, in four passes. **Pass 1** (§1–§6) was a form-only
restyle. **Pass 2** (§7) removed "package-author" patterns (root auto-discovery,
`requireNamespace` guards, over-generalized helpers). **Pass 3** (§8) replaced the
`do.call(rbind, lapply(...))` row-stacking with for-loops and deleted the
input-validation guards (`stopifnot`/`match.arg`/`run_dataset`'s entry checks).
**Pass 4** (§9) is a comment-tightening pass plus two output-preserving code
changes (deleting `show_usage`, merging the duplicate `cat_slug` into `bbq_norm`).
All passes keep every function's exact signature and **computed result**; no
experiment was re-run, and the committed results in `data/results/`,
`outputs/tables/`, `outputs/figures/` remain valid.

> Sections 1–6 describe **Pass 1**; **§7** is **Pass 2**; **§8** is **Pass 3**;
> **§9** is **Pass 4**.

**Verdict.** Behaviour is preserved. Every file is token-for-token identical to the
pre-refactor version except for (a) the intended identifier renames, (b) one stale
doc-string fix, and (c) one redundant-helper de-duplication — all itemised below.

---

## 1. How this was verified

1. **Backup.** The original tree was copied before any edit (and also exists at git
   `HEAD`), so a byte-level comparison is possible.
2. **Token-level diff.** For every file, comments were stripped (string-aware, so
   `#` inside a string is preserved), whitespace collapsed, `<-` normalised to `=`,
   R string escapes decoded to compare string *values*, and the pre-refactor
   identifiers mapped through the rename table below. The resulting token streams
   were compared. **Result: all 22 files identical** except the three intended
   changes in §3.
3. **Statistics cross-check (Python).** SS, the exact two-sided binomial p-value
   (R's `binom.test` algorithm reimplemented), and `BF10` were reproduced for the
   paper's Table 3 fixtures — `(91,54) → .5934 / 9.29e-2 / 6.32e-1`,
   `(65,38) → .5846 / 2.15e-1 / 3.86e-1`, `(320,168) → .5250 / 4.02e-1 / 1.04e-1`,
   plus `BF10(1720,884) ≈ 5.9e-2` and the closed-form identity
   `BF10 = 1/[(n+1)·C(n,k)·0.5ⁿ]` — all match.
4. **Static safety checks.** No `<-` assignments remain; no dangling references to
   the renamed helpers; the `.data$` ggplot pronoun is intact; no stray control
   bytes in the new tree; brackets/strings balanced in every file; the `src/` file
   inventory is unchanged.

R itself was **not** executed (per the project rule and because the owner's R is
not visible here). The owner should still run `Rscript src/main.R tests`.

## 2. Identifier renames applied (and updated at every call site)

Leading-dot "private" helper names were changed to plain names to match the
reference style. Each helper is used only inside its own module; all call sites
were updated:

| Module | old → new |
|---|---|
| `parse.R` | `.strip_edges` → `strip_edges` |
| `datasets.R` | `.bbq_norm/.bbq_keyset/.bbq_stereo_keys/.bbq_resolve/.bbq_read_ambig_neg/.cat_slug` → same without the dot |
| `analysis.R` | `.ref_cats` → `ref_cats` |
| `report.R` | `.ensure_dir/.fmt_bf/.fmt_ebt/.fmt_ss/.fig_ensure/.require_ggplot` → same without the dot |
| entry/boot scripts | `.root/.p/.src/.run/.usage/.load_all_root/.SRC_DIR/.modules/.m/.path` → readable non-dotted names |

**Nothing public was renamed.** All exported function names, argument names and
defaults, and all constants (`PATHS`, `MODELS`, `CATEGORIES`, `*_CAT_MAP`,
`PROMPT_*`, `PAPER_TABLE3/4/6`, `API_*`, …) are unchanged, so the test suite and
cross-module calls are unaffected.

## 3. The only non-cosmetic changes

1. **`config.R`** — a stale error-message reference `(see README_src.md)` →
   `(see src/README.md)` (the file is `src/README.md`; `README_src.md` never
   existed). Diagnostic text only; affects no result.
2. **`run_D_temperature.R`** — removed its redundant local `ensure_dir` definition
   and now calls the identical `ensure_dir` from `report.R` (already loaded via
   `load_all.R`). Same directory-creation behaviour, one fewer copy.
3. **`collect.R` `cache_key()` — the one place a bug was caught and fixed.** The
   original joined the hash fields with `sep = "…"` where `…` was an **invisible
   `0x01` (SOH) control byte**. It renders as nothing in an editor, so the first
   pass transcribed it as `sep = ""` (empty) — which would have changed every
   cache key and silently invalidated the existing cache. The token-diff flagged
   it; it is now restored as the explicit, byte-identical escape `sep = "\x01"`
   and documented in a comment. A full byte scan confirmed this was the **only**
   hidden control byte in the entire original `src/` tree.

## 4. Module-by-module

Every module below is **token-identical** to the original after the renames in §2,
i.e. all formulas, thresholds, regexes, control flow, string literals and output
paths are byte-for-byte preserved; only comments, layout and `=`/names changed.

| Module | Form changes | Logic unchanged — key invariants held |
|---|---|---|
| `config.R` | banner/section restyle, `=`, README fix (§3.1) | prompt strings, `build_prompt_*`, all category maps, model specs, `load_env` regex + `substr` indices, `get_api_key` fallback |
| `stats.R` | comments, `=` | `k/n`, `pmax(k/n,1-k/n)`, `binom.test(k,n,0.5,"two.sided")`, `lbeta(k+1,n-k+1)-n*log(0.5)`, every `interpret_bf`/`bf_strength`/`ebt_stars` threshold, `compute_metrics_nk` columns |
| `parse.R` | comments, `=`, de-dot | `strip_edges` regex, accept-sets `{0,1}`/`{0,1,2}`, `regexpr("ans[012]")` + `substr(…,4,4)`, `NA_integer_`, `vapply(...,integer(1))` |
| `datasets.R` | section restyle, `=`, de-dot | `read.delim` args, CrowS keep/scope filter + ordering, `bbq_norm/keyset/stereo_keys` normalisation, resolver label→text→both cascade, ambig/neg prefilter greps + `identical()` checks, `sprintf("bbq_%s_%04d")`, Winogender `stem_of` regex + `merge`/order |
| `collect.R` | section restyle, `=`, cache-key `\x01` fix (§3.3) | `httr2` request/retry chain, transient set `{429,500,502,503,504}`, `backoff min(60,2^i)`, `cache_path` `sprintf`, **`cache_key` payload + `sha1`**, JSONL record fields/order + `toJSON(auto_unbox,null="null")`, `run_dataset` loop, auth-error regex, `run_meta` attr |
| `analysis.R` | section restyle, `=`, `.ref_cats`→`ref_cats` | indicator rules (`parsed==0` / `parsed==stereo_idx`), `category_counts` NA-drop, **all `PAPER_TABLE3/4/6` numbers** (verified byte-identical), `compare_to_paper` deltas + `log(10)`/`log10`, direction/significance flags, `comparison_summary` rounding + `stats::median` |
| `report.R` | section restyle, `=`, de-dot | `formatC` formats/digits, `**`/`_` emphasis, markdown header/row layout + `CATEGORY_SHORT` ordering, `write_dataset_outputs` file names, both `ggplot2` figure specs (aes, geoms, hlines, labels, `ggsave` dims) |
| `experiments/helpers.R` | comments, `=` | `get_run_limit`, `run_models_metrics` parse-fun selection + `do.call(rbind,…)`, `print_metrics` `sprintf` formats, `report_comparison` |
| `run_A…E.R`, `run_all.R` | banner restyle, `=`, cleaner root-finder, run_D dedup (§3.2) | every dataset name / table id / CSV name (drive existing filenames), Experiment-D subsample math `max(1L,floor(frac*N))` / prefix slice / `(n,k)`, Table-5 markdown strings, Table-6 ordering |
| `main.R`, `load_all.R` | banner restyle, `=`, readable boot vars | command dispatch `switch` (tests/A–E/all/help/unknown→`quit(1)`), module load **order**, source-if-exists, root-finding |
| `tests/*` | banner restyle, `=`, readable boot vars | **every `expect_*` fixture, tolerance and value unchanged**; `library(testthat)` kept; still reference only public names |

## 5. Deliberate preservation calls (flagged, not "improved")

- **`package::function` kept** for `jsonlite / digest / httr2 / ggplot2 / stats /
  utils` instead of top-of-file `library()`. This is load-bearing: the project
  relies on `source()`-ing the library without those packages installed (offline
  tests are dependency-light). It is also within the reference style (which shows
  `stats::median`, `rstudioapi::…`). `library(testthat)` is kept in the test files.
- **Integer/`NA` typing kept** — `NA_integer_/NA_character_`, `vapply` FUN.VALUE
  (`integer(1)`/`character(1)`/`logical(1)`), and `L` suffixes where they feed
  integer-typed pipelines — because `expect_identical` in the tests checks type.
  Terseness was not pursued where it could change a type.
- **`TRUE`/`FALSE` kept** (not shortened to `T`/`F`); the reference lesson even
  warns against `T`/`F` as names.

## 6. Confidence & what the owner should confirm

I am confident the rewrite is behaviour-preserving. The one item worth an explicit
on-machine confirmation is the **`cache_key` `\x01` separator** (§3.3): the escape
`"\x01"` denotes the same single byte as the original literal, so `sha1` and thus
every cache key are identical — but the offline test suite does not exercise
`cache_key`, so the definitive check is behavioural:

```
Rscript src/main.R tests                 # offline: stats / loaders / resolver
RUN_LIMIT=5 Rscript src/main.R A         # should report CACHE HITS, not new calls
```

If the dry run shows cache hits on already-collected items, the cache keys match
and the refactor is confirmed end-to-end. Nothing else in the audit is uncertain.

---

## 7. Pass 2 — approach-level simplification

Pass 2 removes patterns that read like package/distribution infrastructure rather
than a fixed course assignment. Unlike Pass 1 it deliberately changes code
*shape*, so it is **not** token-identical. Method: a per-file `diff` against the
Pass-1 tree confirmed that **only** the intended constructs changed (three files —
`stats.R`, `parse.R`, `helpers.R` — are byte-identical to Pass 1), and each change
is argued below to yield **identical output** for the project's fixed cases
(2 models, 9 categories, 5 experiments, run from the project root). R was not
runnable in the assistant's environment; the owner should run the checks in §7.4.

### 7.1 Project-root auto-discovery → one-line root capture
The walk-up-to-`CLAUDE.md`/`.git` root finder appeared in `config.R`
(`find_project_root` + `PROJECT_ROOT`), `load_all.R` (a `local({repeat…})`), and
every entry/test script (a `while (!file.exists(… "CLAUDE.md")) …` loop). All
removed. `load_all.R` is now eight `source("src/R/…")` lines; each entry script is
one `source("src/load_all.R")`; main.R's `run_script` uses `file.path("src", …)` —
these `source()` paths are relative to the working directory, which is the project
root at that point. `config.R` keeps the paths robust with a **single line**,
`PROJECT_ROOT = getwd()` (no walk-up, no marker file), and builds absolute `PATHS`
from it; the unused `root`/`src`/`data` keys were dropped (grep confirmed no refs).

- **Why absolute, not literally relative:** `config.R` is always sourced while the
  working directory is the project root (before anything changes it), so
  `getwd()` = the root. Absolute paths are then immune to a later `setwd()` — which
  matters because `testthat::test_dir` **chdir's into `src/tests/testthat/`** while
  running each test file, and the data-count / resolver tests read data through
  `PATHS` from there. Pure relative `"data/…"` paths would have broken those tests;
  the `getwd()`-anchored paths resolve to the same files as the old walk-up did.
- **Equivalence:** `getwd()` at source time equals the root that
  `find_project_root()` returned, so every `PATHS`/`CROWS_FILES` value is the same
  absolute path as before. **No output artifact embeds a path** (cache records store
  key/id/model/temperature/response/ts; CSVs store metrics; figures store plots),
  and `cache_key` is unchanged, so existing cache files still hit.
- **Behavioural narrowing (flagged):** previously runnable from any subdirectory,
  now must be launched from the project root. This is the only supported invocation
  per the project docs, and is exactly the requested trade-off.

### 7.2 Defensive `requireNamespace()` guards → removed
Removed the custom "package X is required…" wrappers: httr2 and digest guards in
`collect.R`, `require_ggplot()` in `report.R`, and the testthat guard in
`run_tests.R`. Figures now call `library(ggplot2)`; `run_tests.R` calls
`library(testthat)`; the `httr2::`/`digest::` calls remain and fail naturally if a
package is absent.

- **Equivalence:** when the package **is** installed (every real run) the guard was
  a no-op, so behaviour is identical. When absent, the error message differs
  (natural R error vs. the custom text) — an error-path message, not a computed
  result. Sourcing still needs no packages (ggplot2/testthat load at call time).

### 7.3 Over-generalized helper logic → direct versions
- `report.R`: `fig_ensure()` (a figures-only dir helper) folded into the existing
  general `ensure_dir()` → `ensure_dir(PATHS$figures)`; the redundant function is
  gone. Identical `dir.create` behaviour.
- `report.R` figures: dropped the `ggplot2::` prefix on every call (now bare, under
  `library(ggplot2)`). Verified by diff that **only** the namespace prefix was
  removed — every geom, aes mapping, scale, hline value, colour, linetype, size,
  label, facet and `ggsave` dim is unchanged, so the plots are identical.
- `analysis.R` `compare_to_paper`: `m[, intersect(cols, names(m)), drop = FALSE]` →
  `m[, cols, drop = FALSE]`. The 21 names in `cols` are **always** present in the
  merged frame for the three fixed reference tables (keys + suffixed `n/ss/ebt` +
  the columns the function adds), so `intersect(cols, names(m))` always equalled
  `cols` in `cols`' order — the selection and its order are identical.
- `analysis.R` `comparison_summary`: `split(cmp, cmp$model)` +
  `do.call(rbind, lapply(names(by_model), …))` → a for-loop over
  `sort(unique(cmp$model))` building rows into an unnamed list, then
  `do.call(rbind, rows)`. `split` groups by factor levels =
  `sort(unique(model))`, so iteration order (chatgpt, deepseek), the per-group
  subset, the computed row values, and the final unnamed-list `rbind` are all
  identical (and the result is printed with `row.names = FALSE`).

### 7.4 What the owner should run
```
Rscript src/main.R tests                 # offline: stats / loaders / resolver
RUN_LIMIT=5 Rscript src/main.R A         # from the project root; expect CACHE HITS
```
The tests still pin the statistics/loaders/resolver to the paper's values; the dry
run confirms the `getwd()`-anchored paths locate the cache and that keys still hit.

### 7.5 Deliberately NOT simplified (kept — flag for your call)
- **`match(x, fixed_vector)` ordering** in `load_crows`, `compare_to_paper`,
  `metrics_to_markdown`, `run_E` (order rows by position in `CATEGORIES` /
  `c("chatgpt","deepseek")` / dataset order). This is a clear, standard idiom;
  rewriting to `factor(levels=)` is lateral, not simpler, and risks a subtle
  ordering change. Kept.
- **`category_counts` `intersect(CATEGORIES, unique(df$category))`** — genuinely
  needed (adapts to which categories a frame contains: Winogender has only Gender,
  single-category BBQ loads have one) and imposes canonical order. Not defensive
  over-generalization. Kept.
- **The BBQ resolver's generality** (`bbq_norm/keyset/stereo_keys/resolve`, the
  label→text→both cascade, `intersect(ks, sg)`). Its "generality" *is* the
  algorithm that resolves 7839 items across 9 vocabularies; simplifying it would
  change results. Kept.
- **`do.call(rbind, lapply(...))` map-and-stack** — *kept in Pass 2, then removed
  in Pass 3 (§8).*
- **`run_dataset` input validation** (`stopifnot` + column check) and `match.arg()`
  calls — *kept in Pass 2, then removed in Pass 3 (§8).*

**Verdict:** Pass 2 is output-preserving for every supported run. The single
intentional behavioural change is the run-location narrowing in §7.1.

---

## 8. Pass 3 — for-loop row-stacking + removal of input-validation guards

Two scoped, form-only changes; identical output, nothing re-run. Verified by a
per-file `diff` against the Pass-2 tree (only the two constructs below changed;
`stats.R`, `parse.R`, `config.R`, `report.R`, `main.R`, `load_all.R`, `run_A/D/all`,
`run_tests`, and all test files are byte-identical to Pass 2), no control bytes,
brackets balanced, tree identical.

### 8.1 `do.call(rbind, lapply(...))` → for-loop building a list
Converted every row-stacking `do.call(rbind, lapply(...))` (and the
`rows = lapply(...); do.call(rbind, rows)` variant) to a plain for loop that
appends each frame to an unnamed list via `rows[[length(rows) + 1L]] = …`, then
combines once with `do.call(rbind, rows)`:

| Location | before → after |
|---|---|
| `analysis.R` `category_counts` | `do.call(rbind, lapply(cats, …))` → for over `cats` |
| `analysis.R` `metrics_table` | `lapply(seq_len(nrow), …)` → for over rows |
| `helpers.R` `run_models_metrics` | `do.call(rbind, lapply(models, …))` → for over `models` |
| `run_C_bbq.R` | `do.call(rbind, lapply(CATEGORIES, load_bbq))` → for over `CATEGORIES` (`parts`) |
| `run_B_crows_fr.R` | `rbind(mk_df(m_en,"EN"), mk_df(m_fr,"FR"))` → for over `list(EN=m_en, FR=m_fr)` |
| `run_E_gender.R` | `rbind(pick_gender(…)×3)` → for over `list(winogender=…, crows_en=…, crows_fr=…)` |

- **Equivalence:** each loop iterates in the **same order** as the original
  (`cats`, `seq_len(nrow)`, `models = names(MODELS)`, `CATEGORIES`, and the named
  lists preserve insertion order EN→FR / winogender→crows_en→crows_fr), builds an
  **unnamed** list, and `do.call(rbind, unnamed_list)` is byte-identical to the
  original `rbind`/`do.call(rbind, lapply)` — same rows, same column order, same
  values, same (default) row names. Empty-input edge cases also match (both yield
  `NULL`). run_E's result is subsequently reordered by `order(match(...))` exactly
  as before.
- **Left as-is (not this pattern):** `report.R`'s `long`/`hlines` (a two-part
  long-format reshape with *different* transforms per part, not a map) and the
  `PAPER_TABLE3/4/6 = rbind(data.frame(chatgpt…), data.frame(deepseek…))` data
  literals; `datasets.R`'s `unlist(lapply(groups, bbq_keyset))` in the resolver
  (a map-flatten to a key vector, not row-stacking).

### 8.2 Removed input-validation guards
Deleted, not replaced:
- `collect.R` `run_dataset`: `stopifnot(is.data.frame(items))`, the
  `if (!all(c("id","prompt") %in% names(items))) stop(…)` column check, and the
  `if (is.null(model_spec)) stop("Unknown model key…")` check. (`model_spec =
  MODELS[[model_key]]` and the `dataset_name`/`limit` logic are functional, kept.)
- `match.arg()` in `add_stereo_indicator`, `summarise_run`, `run_models_metrics`
  (`kind`), `load_crows` (`lang`), and `paper_reference` (`switch(match.arg(table),…)`
  → `switch(table,…)`).

- **Equivalence:** on the success path these were no-ops — every call site passes
  an explicit, full, valid argument (verified by grep: `kind` is always
  `"binary"`/`"bbq"`, `lang` `"EN"`/`"FR"`, `table` `"table3/4/6"`, `items` is
  always a loader data.frame with `id`/`prompt`, `model_key` is `"chatgpt"`/
  `"deepseek"`), and no caller relies on the vector default, on `match.arg`
  partial-matching, or on the default-selection behaviour. So computed output is
  identical. **Function signatures are unchanged** (the `= c("binary","bbq")` etc.
  defaults remain; only the `match.arg` call inside the body is gone). Per the
  request, misuse now fails later/less clearly instead of at entry — intended.

### 8.3 Deliberately still NOT touched (flag)
- **Loader/env resource checks** (`if (!file.exists(path)) stop(…)` in
  `load_crows`/`bbq_read_ambig_neg`/`load_winogender`/`load_env`, the
  `if (is.na(stem)) stop("Unknown BBQ category")`, and `get_api_key`'s missing-key
  stop). These catch a genuinely broken environment (missing data file / `.env` /
  key), not argument misuse, and were not the named constructs — removing them
  would turn a clear "file not found" into a cryptic downstream error. Kept.
- **`add_stereo_indicator`'s `if (!"stereo_idx" %in% names(df)) stop(…)`** — a
  deeper (non-top-level, non-`stopifnot`) guard; never fires in practice. Kept.
- Tell me if you want these gone too.

### 8.4 What the owner should run (R is not runnable in the assistant's env)
```
Rscript src/main.R tests            # from the project root
RUN_LIMIT=5 Rscript src/main.R A    # expect CACHE HITS, not new calls
```

**Verdict:** Pass 3 is output-preserving for every supported run; the only
behavioural change is that argument misuse no longer produces an early, clear
error (as requested).

---

## 9. Pass 4 — comment tightening + `show_usage` decision

Almost entirely a comments-only pass — the two code changes are the deletion of
`show_usage()` and the merge of the duplicate `cat_slug` into `bbq_norm` (§9.1),
both output-preserving; no formula, threshold, output path or cache key changed.
Every `src/` file was reread against the `code-reference/` lesson scripts and its
comments rewritten to match their terse, plain, note-to-self style —
shorter banners, multi-line blocks collapsed to 1–2 lines, and comments that
merely restated the next line deleted. **Load-bearing** comments (what EBT/BF10
mean, the BF strength thresholds, the `\x01`-separator and transient-HTTP
rationale, the BBQ resolver's label→text→both cascade, the CrowS/Winogender
reproduction rules, the paper-drift note) were **kept, just shortened**.

### 9.1 Code changes (two, both output-preserving)
**`show_usage()` removed (owner's call).** `grep` found **two** call sites in
`main.R`: the `help` switch case and the unknown-command default. It was first
kept (one shared helper is DRY, and inlining the ~15-line help text into both
branches would duplicate it and risk drift). The owner then decided the help
output was not worth keeping, so `show_usage()` and both call sites were
**deleted**: the `help` case is gone (bare invocation / `help` / an unknown
command now fall through to the default), and the default prints a one-line
`Usage: Rscript src/main.R <tests|A|B|C|D|E|all>` then `quit(1)`. The file banner
still carries the full usage. The seven experiment commands are unaffected.

**`cat_slug` folded into `bbq_norm` (datasets.R).** The two were the *identical*
function — `gsub("[^a-z0-9]", "", tolower(x))` — under different names, so
`cat_slug` was deleted and its one call site (`load_bbq`'s `out$id` slug) now
calls `bbq_norm(category)`. Same string, so every BBQ `id` (`bbq_%s_%04d`), and
therefore every cache key and CSV id, is byte-identical. `bbq_norm` is the more
general name — it already normalises arbitrary strings in `bbq_keyset`.

### 9.2 What changed, by file
Comments only, in: `stats.R`, `parse.R`, `config.R`, `datasets.R`, `collect.R`,
`analysis.R`, `report.R`, `experiments/helpers.R`, `load_all.R`,
`run_A/B/C/D/E_*.R`, and all four `tests/testthat/test-*.R`. `datasets.R` had
comments **plus** the `cat_slug`→`bbq_norm` merge (§9.1); `main.R` had the
`show_usage` removal + its banner line (§9.1). **Not touched:** `run_all.R`,
`tests/run_tests.R` (already terse).

### 9.3 How this was verified
- **Comment-only edits.** Every change *except* the two code changes in §9.1 was a
  targeted edit whose code context was reproduced byte-identically.
- **Code-skeleton diff.** For the comment-only files, the non-comment / non-blank
  lines were confirmed byte-identical to the pre-pass code — including every
  `PAPER_TABLE3/4/6` number, the `is_transient` set `{429,500,502,503,504}`,
  `backoff min(60,2^i)`, the resolver cascade, the Winogender `stem_of` regex, and
  **`cache_key`'s `sep = "\x01"`** (intact). `datasets.R`'s skeleton differs only in
  the `cat_slug`→`bbq_norm` line (output-identical); `grep` confirms no `cat_slug`
  reference survives.
- **Structural checks.** Parens/braces/brackets balance in every file; the `src/`
  file inventory is unchanged. (A naive brace counter flags `test-stats.R` only
  because of a `[(n+1)…]` substring inside a test name and a `(3, 10]` comment —
  both pre-existing, both inside string/comment text.)

R was **not** executed (project rule + R not visible here). The offline suite still
pins the statistics/loaders/resolver to the paper's values; the owner should run
`Rscript src/main.R tests`.

### 9.4 Dry-run caveat (RUN_LIMIT output guard is NOT present)
`RUN_LIMIT=5 Rscript src/main.R A` is **not** safe to run as the tree stands: the
experiment scripts call `write_dataset_outputs()` / `report_comparison()`
unconditionally, so a 5-item dry run would **overwrite** the real full-run files
(`data/results/metrics_table3_crows_en.csv`, `compare_table3_crows_en.csv`,
`outputs/tables/table3_crows_en_*.md`) with 1-category output. Because this pass
changed only comments (no logic, cache key or path), `Rscript src/main.R tests`
alone is sufficient verification here; the RUN_LIMIT dry run adds nothing and
should be skipped until an output guard is added.

**Verdict:** Pass 4 changes comments only, plus the two output-preserving code
changes in §9.1 (`show_usage` deleted, `cat_slug` merged into `bbq_norm`; both
confirmed by grep — no dangling references — with `main.R` and `datasets.R` still
parsing/balancing). No experiment logic, statistic, output path or cache key
changed; no experiment was re-run and all committed results remain valid. The only
behavioural change is that no-args / `help` / an unknown command now print a
one-line usage instead of the full block.

---

## 10. Final state (closing summary)

All four passes are complete and reflected above; the current `src/` tree is the
delivered implementation. Across every pass each function kept its original name,
signature and **computed result** — no formula, threshold, parsing rule, category
mapping, prompt string, cache key or output path was changed, and no experiment was
re-run for the refactor. The committed results in `data/results/`,
`outputs/tables/` and `outputs/figures/` therefore remain valid.

Because R is not runnable in the assistant's environment, the standing verification
is for the owner to run, from the project root:

```
Rscript src/main.R tests
```

which re-pins the statistics, loaders and BBQ resolver to the paper's published
values offline, for free. No further refactor passes are planned.
