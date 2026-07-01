# Data sources

All three datasets used in the paper ("Detecting implicit biases of large language models
with Bayesian hypothesis testing", Si, Jiang, Su & Carin, 2025).

## crows_pairs/
- `crows_pairs_EN_revised+210.csv` — English CrowS-Pairs, extended (+210 pairs), tab-separated.
  Columns: `sent_more`, `sent_less`, `stereo_antistereo`, `bias_type`.
- `crows_pairs_FR_languagearc_contribution+210.csv` — French version (Neveol et al. 2022).
- Source: pulled directly from the paper's own code repo
  https://github.com/shijing001/bayes_factor_bias_detection
  (original canonical source: https://gitlab.inria.fr/french-crows-pairs/acl-2022-paper-data-and-code —
  not reachable from this sandbox's network allowlist, so sourced from the mirror above instead).

## bbq/
- 11 `.jsonl` files, one per bias category (Age, Disability_status, Gender_identity,
  Nationality, Physical_appearance, Race_ethnicity, Race_x_SES, Race_x_gender, Religion,
  SES, Sexual_orientation).
- `templates/` — the underlying question templates + vocabulary used to generate the jsonl items.
- Source: https://github.com/nyu-mll/BBQ

## winogender/
- `all_sentences.tsv` — full sentence set (male/female/neutral pronoun variants).
- `templates.tsv`, `occupations-stats.tsv` — templates and occupation gender-stat priors.
- Source: https://github.com/rudinger/winogender-schemas

## Note on the paper's methodology (relevant when writing R loaders)
- CrowS-Pairs / Winogender: used as-is, sentence pairs (stereotypical vs anti-stereotypical).
- BBQ: paper only uses the **negative questions under the ambiguous context** subset
  (see "Implementation details" in the paper) — you'll need to filter each jsonl by
  `context_condition == "ambig"` and `question_polarity == "neg"` before use.
