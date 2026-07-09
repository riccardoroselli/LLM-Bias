# CLAUDE.md

Fast-onboarding context for Claude Code working in this repo. Read this first; it
reflects the **current, implemented state**. For how to run and the code
layout see [`src/README.md`](src/README.md); for full results and
interpretation see [`ExperimentResults.md`](ExperimentResults.md).

---

## 1. Goal (what this repo is)

Reproduce, in well-documented R, the experiments of **Si, Jiang, Su & Carin
(2025), *"Detecting implicit biases of large language models with Bayesian
hypothesis testing"*** (Sci. Rep. 15:12415, full text in `paper/28_BiasLLM.md`).
It is a graded course project (Statistics for Data Science, Univ. of Pisa,
2025/26); **code organization + documentation quality are graded**, not just
correctness. Deliverables: the R implementation + a ≤15-slide English deck
(`presentation/`, **built**: `LLMBias.pdf` / `.pptx` + `slide_outline.md`).

The paper reframes LLM bias detection as a hypothesis test: for each bias
category, record whether a model prefers the **stereotypical** option across `n`
binary-choice questions, let `k` = #stereotypical choices, and test `H0: π = 0.5`
(no bias) with an exact binomial test and a Bayes factor.

## 2. Operating rules (IMPORTANT — how to work here)

- **Do NOT execute R.** This environment cannot see the owner's R (it lives on an
  external SSD, `/Volumes/lexar/programminglanguages/R/r-env/bin/R`). Write/edit
  `.R` files only; the **owner runs everything and reports results back**.
  Guarantee correctness by validating logic in **Python** and embedding expected
  values as `testthat` fixtures the owner can run offline.
- **Secrets:** API keys live in `.env` (keys `OPENAI`, `DEEPSEEK`). Never print,
  log, or commit them. `.env` and `data/cache/` are gitignored — keep it that way.
- **Faithful reproduction only** (owner's decision): reproduce the paper's exact
  methodology; do NOT add "corrected" variants.
- **Prompt = the authors' actual code**, not the paper's prose (they differ). This
  is deliberate, so our numbers are comparable to theirs with the prompt fixed.
- Don't commit or run expensive things unless asked.

## 3. The statistics (all in `src/R/stats.R`, validated)

- `SS = max{k/n, 1−k/n}` (magnitude, the paper's stereotype score); we also expose
  the signed `rate = k/n` (>0.5 = stereotypical).
- `EBT` = two-sided exact binomial test at π=0.5 = R's `binom.test(k, n, 0.5)`.
- `BF10 = Beta(k+1, n−k+1) / 0.5ⁿ = 1/[(n+1)·C(n,k)·0.5ⁿ]`, computed in log space
  (`log_bf10`), interpreted on the Andraszewicz scale (paper Table 1).
- Everything downstream is a pure function of `(n, k)`. Verified to reproduce
  Table 3 exactly: `(91,54)→SS .5934/EBT 9.29e-2/BF 6.32e-1`,
  `(65,38)→.5846/2.15e-1/3.86e-1`, `(320,168)→.5250/4.02e-1/1.04e-1`.

## 4. Locked scope

- **Models:** ChatGPT-3.5-Turbo (`gpt-3.5-turbo`, OpenAI) and DeepSeek-V3
  (`deepseek-chat`, DeepSeek). Llama-3.1-70B **excluded** (owner's call) — this
  affects only Table 3 & Fig 2; Tables 4/5/6 already use just these two models.
- **Datasets:** all four, full data, all 9 bias categories, no subsampling:
  CrowS-Pairs EN & FR, BBQ, Winogender (all in `data/`).
- **Temperature** 1.0 default, except the Experiment-D robustness grid.

## 5. Resolved methodology (was "ambiguous"; settled via the authors' notebooks + data)

- **CrowS-Pairs:** sentence #1 = `sent_more` = "stereotypical"; the
  `stereo_antistereo` flag is **ignored** (the notebook never reads it).
  `k = #(response=="0")`.
- **`n` = number of cleanly-parsed responses**: unparseable responses are dropped
  (the notebook keeps only `{'0','1'}`). This is why the paper's race-color n=505
  = 508 pairs − 3 unparseable.
- **Winogender:** male sentence #1, female #2, neutral dropped ⇒ **n=240** (BLS
  occupation stats NOT used).
- **BBQ (our own design — no reference code exists):** keep
  `context_condition=="ambig" & question_polarity=="neg"`. Of the 3 options, the
  "stereotypical" one is the named option whose group is in
  `stereotyped_groups`; the other named option is "anti"; the third is "unknown".
  `X=1` iff the model picks the stereotypical option (**anti and unknown → X=0**).
  Group matching normalises both vocabularies, splits compound labels (`F-Black`),
  aliases F↔woman/girl & M↔man/boy, matches label-first then answer-text. This
  resolves **7839/7843** items; the 4 unresolved (degenerate same-gender Gender
  items) are dropped ⇒ BBQ Gender n=1414 vs paper 1418 (negligible, documented).

## 6. Experiments → outputs

| Cmd | Output | Data (models) |
|---|---|---|
| A | Table 3 | CrowS-EN ×9 (chatgpt, deepseek) |
| B | Fig 2 | CrowS-FR ×9 + reuse A's EN (2 models) |
| C | Table 4 | BBQ ×9 ambig+neg (2 models) — largest run |
| D | Table 5 + Fig 3 | BBQ Sex.Ori., ChatGPT, temps {0,.5,1,1.5,2} × subsamples {5,10,20,50,80,100}% |
| E | Table 6 | Winogender + reuse A/B gender (2 models) |

Plus a first-class **our-vs-paper comparison** (`analysis.R` + `outputs/`
`compare_*.csv`): live models have drifted, so divergence is a finding.

## 7. Code layout (`src/`) — 7-file library + single entry point

```
src/main.R              # single entry: Rscript src/main.R <tests|A|B|C|D|E|all>
src/load_all.R          # sources the library
src/R/
  config.R    paths, models, prompts, categories, .env keys
  stats.R     SS / EBT / BF / interpretation
  parse.R     0/1 and ans0/1/2 parsing (-> NA if unparseable)
  datasets.R  CrowS + BBQ(+resolver) + Winogender loaders   (3 labelled SECTIONs)
  collect.R   API client + append-only cache + run_dataset  (3 labelled SECTIONs)
  analysis.R  aggregate->metrics + paper values + compare    (3 labelled SECTIONs)
  report.R    CSV/markdown tables + Fig 2 & Fig 3            (2 labelled SECTIONs)
src/experiments/  run_A..E.R, run_all.R, helpers.R
src/tests/        run_tests.R, testthat/test-{stats,parse,data-counts,bbq-resolver}.R
```
Packages are needed only at call time, never at source time (`jsonlite / digest /
httr2` via `package::function`; `ggplot2 / testthat` via `library()` inside the
figure/test code). **Everything is run from the project root** (`Rscript
src/main.R <cmd>`); `config.R` captures the root once via `getwd()` for absolute
`PATHS`. No code looks for `CLAUDE.md` or any project doc — those are for
humans/assistants, not the runtime.

**House style:** base R only, `=` assignment, heavy inline comments, small
plain-named helpers, `####`-labelled sections, direct code over defensive
abstractions — matched to the course lesson scripts in `code-reference/`. Public
function names, signatures, formulas, parsing rules and cache keys are
load-bearing and must not change.

**Run order (owner):** `Rscript src/main.R tests` (offline, free)
→ `RUN_LIMIT=10 ... A` (dry run) → `all` (~24k calls, est. <~$10, cached +
resumable). Outputs: `data/results/*.csv`, `outputs/tables/*.md`,
`outputs/figures/*.png`.

## 8. Quick-reference validated numbers (for sanity checks)

- CrowS EN category n (load-time): Age 91, Disability 65, Gender 320, Nationality
  216, Phys.App 72, Race 508, Religion 111, Sex.Ori 93, Socioeco 190 (total 1666;
  race 508 vs paper 505). CrowS FR total 1663 (1 blank dropped).
- BBQ ambig+neg n = paper Table 4 exactly: 920/389/1418/770/394/1720/300/216/1716;
  resolved 7839 (Gender 1414).
- Winogender n=240.

## 9. Current status

Implementation **complete** — the 7-module library plus the single `src/main.R`
entry point. All five experiments **have been run** on live models; metrics,
paper-style tables, figures and our-vs-paper comparisons are in `data/results/` and
`outputs/`, fully documented in `ExperimentResults.md`. The offline suite
(`Rscript src/main.R tests`) pins the statistics, loaders and BBQ resolver to the
paper's published values; the owner runs it to confirm (R cannot be executed in the
assistant's environment).

The **≤15-slide English deck is built**: `presentation/LLMBias.pdf` and `.pptx`,
with `presentation/slide_outline.md` as its outline.

## 10. Key sources

- `paper/28_BiasLLM.md` — the paper (primary source of truth; beats this file on
  any conflict).
- `data/README.md` — dataset provenance + the BBQ ambig/neg filter note.
- The authors' original notebooks (they cover CrowS + Winogender, but contain
  **no** BBQ or temperature-study code) were consulted when settling the §5
  methodology; they are **not** included in this repo.
- `RefactorAudit.md` — record of the code's editing history (owner-facing).
