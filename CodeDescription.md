# CodeDescription.md — Structure of the R Code (`src/`)

A complete structural map of the R implementation: what each script does, how the
scripts depend on and call one another, and how data flows from a dataset file to
a result CSV/figure. Detailed enough to understand the codebase **without opening
`src/`**.

This is one of three source-of-truth documents:

| Document | Domain |
|---|---|
| **ProjectContext.md** | Purpose, research question, statistical theory & formulas |
| **CodeDescription.md** (this file) | Structure of the R code — scripts, dependencies, data flow |
| **ExperimentResults.md** | The experiments run and the numbers obtained |

The **statistics** the code implements (SS, EBT, BF₁₀, the interpretation scale)
are defined in **ProjectContext.md §4**; this file describes *where and how* they
are implemented, not what they mean. The **outputs** the code produces are
catalogued in **ExperimentResults.md**.

---

## 1. Big picture

- **One entry point:** `src/main.R`. Everything is launched as
  `Rscript src/main.R <command>` (`tests`, `A`…`E`, `all`). There is no other
  supported way to run the project.
- **A 7-module library** in `src/R/`, sourced together by `src/load_all.R`.
- **Thin experiment drivers** in `src/experiments/` that call the library.
- **An offline test suite** in `src/tests/` that pins the library to the paper's
  published values.
- **Portability:** every script finds the project root by walking up to the
  `CLAUDE.md` marker, so it runs from any working directory. External packages are
  referenced as `package::function`, so *sourcing* the library needs nothing
  installed — a package is required only when a function that uses it runs.

### Layered dependencies
```
config.R          (foundation: paths, models, prompts, categories, .env keys)
   │
   ├── stats.R        pure (n,k) → statistics          [implements ProjectContext §4]
   ├── parse.R        raw text → 0/1 / 0/1/2 / NA
   ├── datasets.R     dataset files → items (id, prompt, …)
   ├── collect.R      items → model responses (+ cache)  (uses parse fn)
   ├── analysis.R     responses → metrics; paper values; comparison  (uses stats)
   └── report.R       metrics → CSV / Markdown / figures  (uses config, ggplot2)
        │
   experiments/helpers.R   orchestration glue (uses collect + analysis + report + parse)
        │
   experiments/run_A..E.R  one driver per experiment (use helpers + datasets + report)
```

---

## 2. End-to-end data flow (one experiment)

```
dataset file ──load_*()──▶ items (data.frame: id, prompt, category, …)
                                   │
             run_dataset() per model  (collect.R)
             ├─ cache hit?  → reuse cached response
             └─ else call_llm() → API → append to data/cache/*.jsonl
                                   │
                      raw_response + parsed choice (parse.R)
                                   │
             summarise_run()  (analysis.R)
             ├─ add_stereo_indicator()  parsed → X (1 = stereotypical)
             ├─ category_counts()       X → per-category (n, k)   [drops X=NA]
             └─ metrics_table()         (n,k) → SS/EBT/BF via stats.R
                                   │
             write_dataset_outputs() (report.R) → data/results/metrics_*.csv
                                                → outputs/tables/*.md
             report_comparison()    (analysis+report) → compare_*.csv
                                     (join with PAPER_TABLE*, agreement summary)
```

The key contract: **`run_dataset` needs only `id` + `prompt` columns and returns
`raw_response`/`parsed`; everything downstream is a pure function of the parsed
choices reduced to `(n, k)`.**

---

## 3. Entry point & loader

### `main.R`
The single entry point. Locates the project root, reads the command-line argument,
and `switch()`es on it: `tests` → runs the test harness; `A`–`E` → sources the
matching experiment driver; `all` → sources `run_all.R`; no/unknown argument →
prints usage. This is the **only** file that documents how to run the project.

### `load_all.R`
Sources every library module **in dependency order** — `config.R` first (it
defines the constants everything else uses), then `stats`, `parse`, `datasets`,
`collect`, `analysis`, `report`, and finally `experiments/helpers.R`. Every entry
script calls this once to make the whole library available.

---

## 4. The library (`src/R/`)

### `config.R` — configuration & API keys
Pure definitions, no side effects (beyond locating the root). Provides:
- **`PATHS`** — all project directories (data, cache, results, figures, tables, `.env`).
- **`MODELS`** — the two model specs (id, provider, model string, base URL, `.env`
  key name, display label). Both use an OpenAI-compatible endpoint.
- **Prompt builders** — `build_prompt_binary(s1,s2)` and
  `build_prompt_bbq(context,question,ans0,ans1,ans2)`, reproducing the authors'
  exact prompt wording (see ProjectContext §7).
- **Category maps** — `CATEGORIES` (the 9, in order), `CATEGORY_SHORT` (table
  headers), `CROWS_CAT_MAP` and `BBQ_CAT_MAP` (raw dataset labels → canonical
  categories).
- **Run parameters** — `DEFAULT_TEMPERATURE`, `TEMPERATURES_ROBUSTNESS`,
  `SUBSAMPLE_FRACTIONS`, and API retry/timeout settings.
- **`.env` loading** — `load_env()` parses `KEY=VALUE`; `get_api_key(model_spec)`
  returns a key, never logging it.

### `stats.R` — the statistics (pure functions of `(n, k)`)
Implements **ProjectContext §4**. No I/O, so it is unit-tested offline.
- `stereotype_rate(n,k)` = k/n; `stereotype_score(n,k)` = max{k/n, 1−k/n}.
- `ebt_pvalue(n,k)` = two-sided `binom.test`; `ebt_stars(p)` = `*`/`**` flags.
- `log_bf10(n,k)` / `bf10(n,k)` — Bayes factor in log space and linear;
  `interpret_bf(bf)` maps to the Andraszewicz labels; `bf_strength(bf)` gives the
  coarse bold/underline flag.
- `compute_metrics_nk(n,k)` — one-row data.frame bundling all of the above; the
  single function the rest of the pipeline calls.

### `parse.R` — response parsing
Turns a raw model reply into a clean choice or `NA` (dropped from `n`).
- `parse_binary(x)` → `0`/`1`/`NA` (tolerates whitespace, quotes, trailing period;
  rejects prose and out-of-range).
- `parse_bbq(x)` → `0`/`1`/`2`/`NA` (accepts `ans0/1/2` any case, or a bare digit).
- `parse_binary_vec` / `parse_bbq_vec` — vectorised forms.

### `datasets.R` — dataset loaders (3 sections)
Each loader returns a data.frame with at least `id`, `category`, and a ready-to-send
`prompt` column. How each maps to binary choices is in ProjectContext §6.
- **CrowS-Pairs:** `load_crows("EN"|"FR")` filters to the 9 categories, drops empty
  sentences, sets sentence #1 = stereotypical, builds the prompt.
  `crows_category_counts()` is a helper used by tests.
- **BBQ:** `load_bbq(category)` reads the ambiguous+negative items and runs the
  **3-way→binary resolver** (`.bbq_resolve` + `.bbq_*` helpers) that identifies the
  stereotyped / anti / unknown option indices by normalising and matching group
  labels; unresolvable items are dropped. `bbq_ambig_neg_count()` reports the
  pre-resolution count (used by tests). This resolver is our own design.
- **Winogender:** `load_winogender()` pairs male/female sentences by shared stem
  (neutral dropped), male = stereotypical → 240 pairs.

### `collect.R` — API client, cache, collection engine (3 sections)
- **`call_llm(model_spec, prompt, temperature, api_key)`** — one client for both
  providers (httr2, with retry/backoff on 429/5xx). Returns content + status;
  never logs the key.
- **Cache** — an append-only JSONL file per (dataset, model, temperature).
  `cache_key()` hashes provider+model+temperature+prompt; `cache_load()` reads a
  file into a hashmap; `cache_get()` looks up; `cache_append()` persists one record.
  This makes runs **resumable** — nothing is ever re-requested.
- **`run_dataset(items, model_key, temperature, parse_fun, limit, …)`** — the
  engine. For each item: return the cached response, else call the API and cache
  it; parse each response with `parse_fun`. A fatal auth error aborts; transient
  failures leave the item uncached for retry. Returns `items` plus `raw_response`,
  `parsed`, `from_cache`, and a `run_meta` attribute (counts of calls / hits /
  drops). Honours a `limit` for small-sample dry runs.

### `analysis.R` — aggregation, paper values, comparison (3 sections)
- **Aggregation:** `add_stereo_indicator(df, kind)` computes `X` (binary: `X=1` iff
  `parsed==0`; BBQ: iff `parsed==stereo_idx`). `category_counts()` reduces to
  per-category `(n, k)`, dropping `X=NA`. `metrics_table()` attaches all statistics
  via `stats.R`. `summarise_run()` chains these into a tagged metrics table.
- **Paper reference:** `PAPER_TABLE3/4/6` hold the paper's published SS/EBT/BF
  values (transcribed verbatim); `paper_reference(table)` returns the right one.
- **Comparison:** `compare_to_paper(ours, table)` joins our metrics to the paper's
  and computes deltas and agreement flags (`same_direction` on H₁/H₀,
  `same_significance` on EBT). `comparison_summary()` aggregates per model
  (% agreement, mean |ΔSS|, median |Δlog₁₀BF|).

### `report.R` — outputs (2 sections)
- **Tables:** `save_results_csv()` writes tidy CSVs to `data/results/`;
  `metrics_to_markdown()` / `write_markdown_table()` render paper-style Markdown
  (categories as columns; SS/EBT/BF rows) to `outputs/tables/`;
  `write_dataset_outputs()` does both for a multi-model table.
- **Figures (ggplot2):** `fig_crosslanguage(df)` draws Fig 2 (log₁₀BF per category,
  EN vs FR); `fig_temperature(df)` draws Fig 3 (BF and p-value vs sample size,
  per temperature). Both write PNGs to `outputs/figures/`.

---

## 5. Experiment drivers (`src/experiments/`)

### `helpers.R` — orchestration glue
Keeps each driver thin:
- `get_run_limit()` — reads the optional `RUN_LIMIT` env var (dry-run cap).
- `run_models_metrics(items, dataset_name, kind)` — the workhorse: runs
  `run_dataset()` for every model (selecting `parse_binary`/`parse_bbq` by `kind`),
  prints per-run progress, and returns the combined per-category metrics via
  `summarise_run()`.
- `print_metrics()` — pretty console table.
- `report_comparison(metrics, table_id, csv_name)` — runs `compare_to_paper()`,
  saves the compare CSV, and prints the agreement summary.

### `run_A_crows_en.R` … `run_E_gender.R` — one per experiment
Each loads its data, calls `run_models_metrics()`, then writes tables/figures and
(where a paper table exists) the comparison. Mapping:

| Driver | Output | Data |
|---|---|---|
| `run_A_crows_en.R` | Table 3 | English CrowS-Pairs ×9 ×2 models |
| `run_B_crows_fr.R` | Fig 2 | French CrowS + reuses A's English cache |
| `run_C_bbq.R` | Table 4 | BBQ ambig+neg ×9 ×2 (largest run) |
| `run_D_temperature.R` | Table 5 + Fig 3 | BBQ Sexual-orientation, ChatGPT, temps × subsamples |
| `run_E_gender.R` | Table 6 | Winogender + reuses A/B Gender rows |

Reuse works through the cache: B/D/E re-request the same `(model, temperature,
prompt)` keys A/C already cached, so they cost nothing new.

### `run_all.R`
Sources `run_A..E.R` in order — the full reproduction. Cached and resumable.

---

## 6. Test suite (`src/tests/`)

Offline, no API, no keys — it re-verifies the delivered code for free.

### `run_tests.R`
The harness: loads the library, then runs every `testthat` file in `testthat/`.

### `testthat/test-*.R`
- `test-stats.R` — the statistics reproduce the paper's **Table 3** values exactly
  on fixed `(n, k)` fixtures (this is what makes the whole reproduction trustworthy
  — see ProjectContext §7).
- `test-parse.R` — parsing accepts clean answers and drops ambiguous prose.
- `test-data-counts.R` — loaders reproduce the paper's per-category sizes.
- `test-bbq-resolver.R` — the BBQ 3-way→binary resolver matches the paper's Table 4
  sizes and resolves 7839 items (the most delicate, un-referenced logic).

---

## 7. Call order — representative experiment (A)

1. `Rscript src/main.R A` → `main.R` sources `experiments/run_A_crows_en.R`.
2. The driver sources `load_all.R` (whole library available).
3. `load_crows("EN")` (**datasets.R**) → items with `id` + `prompt`.
4. `run_models_metrics(items, "crows_en", "binary")` (**helpers.R**):
   - for each model → `run_dataset()` (**collect.R**) → responses (cached or via
     `call_llm`), each parsed by `parse_binary` (**parse.R**);
   - `summarise_run()` (**analysis.R**) → `add_stereo_indicator` → `category_counts`
     → `metrics_table` (**stats.R**) → per-category metrics;
   - results row-bound across models.
5. `write_dataset_outputs()` (**report.R**) → `data/results/metrics_table3_crows_en.csv`
   + `outputs/tables/table3_crows_en_{model}.md`.
6. `report_comparison()` → `compare_to_paper()` vs `PAPER_TABLE3` →
   `data/results/compare_table3_crows_en.csv` + printed agreement summary.

Experiments B–E follow the same shape; D additionally loops over temperatures and
recomputes metrics on nested subsamples, and B/E assemble cross-dataset frames
before writing figures/tables. The concrete numbers these produce are in
**ExperimentResults.md**.
