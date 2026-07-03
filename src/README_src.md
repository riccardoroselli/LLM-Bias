# `src/` — R implementation

Reproduction of Si, Jiang, Su & Carin (2025), *Detecting implicit biases of LLMs
with Bayesian hypothesis testing* (Sci. Rep. 15:12415), for two models
(ChatGPT‑3.5‑Turbo, DeepSeek‑V3) over four datasets.

## Requirements

* R ≥ 4.1 (uses the native `|>` pipe).
* CRAN packages:
  * **Always:** `jsonlite`, `digest`, `httr2` (data loading, cache, API).
  * **Analysis/output:** `dplyr` *(optional)*, `ggplot2` (figures).
  * **Tests:** `testthat`.

```r
install.packages(c("jsonlite", "digest", "httr2", "ggplot2", "testthat"))
```

Modules use `package::function` throughout, so *sourcing* a file never requires a
package to be installed — a package is only needed when a function that uses it
is actually called. The offline tests therefore need only `testthat` (+ `jsonlite`
for the data-count tests).

## API keys (`.env`)

The project root `.env` (gitignored) must contain:

```
OPENAI=sk-...
DEEPSEEK=sk-...
```

Keys are read by `config.R` and never printed, logged, or cached.

## Layout

```
src/
  main.R                    # THE single entry point (dispatches everything)
  load_all.R                # sources the library modules below
  R/                        # the reusable library (7 files)
    config.R                #   paths, models, prompts, categories, .env keys
    stats.R                 #   SS / exact binomial test / Bayes factor (Eq. 4 & 6)
    parse.R                 #   parse 0/1 and ans0/1/2 responses (-> NA if unparseable)
    datasets.R              #   CrowS-Pairs, BBQ (+ resolver), Winogender loaders
    collect.R               #   API client + append-only cache + run_dataset()
    analysis.R              #   aggregate -> metrics, paper's values, our-vs-paper
    report.R                #   CSV / markdown tables + Fig 2 & Fig 3 (ggplot2)
  experiments/
    run_A_crows_en.R ...    #   one driver per experiment (A..E)
    run_all.R               #   A..E in order
    helpers.R               #   orchestration helpers used by the drivers
  tests/
    run_tests.R  smoke_api.R
    testthat/ test-*.R
```

Each merged file in `R/` is split into clearly labelled `SECTION` blocks, so the
7 modules stay easy to navigate.

## Run order — everything goes through `src/main.R`

Run **from inside the project directory** (any subfolder works; scripts locate the
root via `CLAUDE.md`). One command does everything:

```
Rscript src/main.R            # show help / list of commands
Rscript src/main.R tests      # 1. offline tests   — NO API, zero cost. START HERE.
Rscript src/main.R smoke      # 2. live smoke test — a few cents (both models)
RUN_LIMIT=10 Rscript src/main.R A   # 3. small-sample dry run (first 10 items)
Rscript src/main.R all        # 4. the full run: experiments A..E (~24k calls)
```

Individual experiments (all cached + resumable; safe to interrupt):

```
Rscript src/main.R A    # Table 3   English CrowS-Pairs
Rscript src/main.R B    # Fig 2     English vs French CrowS (reuses A)
Rscript src/main.R C    # Table 4   BBQ (largest run)
Rscript src/main.R D    # Table 5 + Fig 3  temperature x sample size (reuses C @ t=1.0)
Rscript src/main.R E    # Table 6   gender across three datasets (reuses A/B + Winogender)
```

What to expect from each step:
* `tests` — confirms the statistics reproduce Table 3 exactly, parsers behave,
  CrowS/BBQ/Winogender counts match the paper, and the BBQ resolver resolves
  7839/7843 items. **If this fails, fix before spending anything.**
* `smoke` — prints two responses per model and confirms cache + resume (second
  run = 0 new calls).
* each experiment — prints a live progress log (cache hits / new calls / parse
  rate), writes its CSV(s) + markdown table(s) + figure(s), and prints an
  agreement summary vs the paper.

## Outputs

* `data/results/*.csv` — tidy metrics + our-vs-paper comparisons (committed).
* `report/tables/*.md` — paper-style tables for the slides.
* `report/figures/*.png` — Fig 2 (cross-language) and Fig 3 (temperature).
* `data/cache/*.jsonl` — raw responses (gitignored, regeneratable).

## Key reproduction choices (see `ProjectStatus.md` for full rationale)

* Prompts follow the **authors' actual code** (not the paper's prose), so our
  numbers are comparable to theirs with the prompt held constant.
* CrowS: `sent_more` is always sentence #1 ("stereotypical"); the
  `stereo_antistereo` flag is not used (matches the authors' code).
* Winogender: male sentence #1, female #2, neutral dropped (n=240).
* BBQ: ambiguous+negative only; the stereotypical option is the one whose group
  is in `stereotyped_groups`; unknown/anti count as X=0; 4 unresolvable Gender
  items dropped (n=1414 vs paper 1418).
* Unparseable responses are dropped from `n` (matches the authors' analysis).
