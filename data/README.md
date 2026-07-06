# `data/` — datasets, cache, and results

The paper's input datasets, the raw API-response cache, and the computed result
tables.

## Input datasets

### `crows_pairs/` — CrowS-Pairs sentence pairs (tab-separated)
- `crows_pairs_EN_revised+210.csv` — English, revised +210. Columns: `sent_more`
  (more stereotypical), `sent_less`, `stereo_antistereo`, `bias_type`.
- `crows_pairs_FR_languagearc_contribution+210.csv` — French (Névéol et al. 2022).
- Source: the paper's repo <https://github.com/shijing001/bayes_factor_bias_detection>
  (canonical French source: <https://gitlab.inria.fr/french-crows-pairs>).

### `bbq/` — BBQ question items (JSON Lines)
- 11 `.jsonl` files, one per category. The pipeline uses **9**; the two
  intersectional files (`Race_x_gender`, `Race_x_SES`) are not among the paper's
  nine categories and are ignored.
- Only **ambiguous-context, negative-polarity** items are used
  (`context_condition == "ambig"` and `question_polarity == "neg"`).
- `templates/` — the source question templates + vocabulary (not read at runtime).
- Source: <https://github.com/nyu-mll/BBQ>

### `winogender/` — Winogender occupation sentences
- `all_sentences.tsv` — male/female/neutral pronoun variants. Neutral is dropped;
  each male sentence is paired with its female counterpart → 240 pairs, with the
  male sentence treated as "stereotypical".
- `templates.tsv`, `occupations-stats.tsv` — templates and BLS occupation stats
  (the stats are **not** used, per the paper's convention).
- Source: <https://github.com/rudinger/winogender-schemas>

## Generated at runtime

- `cache/` — append-only raw API responses, one file per
  (dataset, model, temperature). **Gitignored** (large, regeneratable); makes
  every run resumable.
- `results/` — tidy metrics and our-vs-paper comparison CSVs, written by the
  experiments (committed). `outputs/` holds the human-readable versions.
