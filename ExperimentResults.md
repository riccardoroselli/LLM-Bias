# ExperimentResults.md — Single Source of Truth for the LLM-Bias Reproduction

**Status:** All five experiments (A–E) have been run to completion on live models.
This document reports the **experimental design and every result obtained**, with
pointers to the exact output files. It is one of three source-of-truth documents:
purpose and statistical **theory** are in **ProjectContext.md**, the **code**
structure in **CodeDescription.md**, and the **results** here.

*Raw per-question model answers live in `data/cache/*.jsonl`; computed statistics
in `data/results/*.csv`; formatted tables in `outputs/tables/*.md`; figures in
`outputs/figures/*.png`.*

---

## 1. What this document covers

This file reports the experiments actually run and the numbers obtained. The
project reproduces **Si, Jiang, Su & Carin (2025)** (Scientific Reports 15:12415),
which reframes bias detection as a binomial hypothesis test — **H₀: π = 0.5**
(no bias) vs **H₁: π ≠ 0.5**, with every result a function of `(n, k)`. The full
motivation and the statistical theory (SS, EBT, BF₁₀, the interpretation scale)
are in **ProjectContext.md**; the code that produced these numbers is described in
**CodeDescription.md**.

---

## 2. Notation used in the result tables

Full definitions and formulas are in **ProjectContext.md §4**; the minimum needed
to read the tables below:

- **rate** = k/n — *signed* direction: `>0.5` stereotypical, `<0.5`
  anti-stereotypical, `≈0.5` none.
- **SS** = max{k/n, 1−k/n} — *magnitude* only (always ≥0.5, direction-agnostic).
  **Read `rate` for direction** — this matters most on BBQ (§6), where a high SS
  often comes with a *low* rate (the model avoids the stereotype / answers
  "unknown").
- **EBT** — exact binomial p-value for H₀: π=0.5; `*` p<0.05, `**` p<0.01.
- **BF₁₀** — Bayes factor; `>1` favours bias (H₁), `<1` favours no-bias (H₀).
  Tables/figures often show **log₁₀BF** (positive = bias, negative = no-bias). The
  Andraszewicz interpretation scale is in ProjectContext §4.4.

**CSV columns:** `model, dataset, category, n, k, n_dropped, ss, rate, ebt,
ebt_stars, log_bf10, bf10, bf_interp, bf_strength`. The `compare_*` files repeat
each metric as `_ours`/`_paper` plus **`same_direction`** (agree on H₁/H₀),
**`same_significance`** (agree on EBT), and the deltas.

---

## 3. Scope recap

Two models (**ChatGPT-3.5-Turbo**, **DeepSeek-V3**; Llama-3.1-70B out of scope),
four datasets, all nine categories, temperature 1.0 (except Experiment D). The
prompt is fixed to the authors' code; `n` counts only cleanly-parsed responses;
BBQ's 3-way→binary reduction is our own design. Full scope, methodology decisions,
and deviations from the paper are in **ProjectContext.md §5–§7**.

Because our statistics **provably reproduce the paper's own Table 3 from `(n, k)`**
(pinned by the offline test fixtures, e.g. `(91,54) → SS 0.5934 / EBT 9.29e-2 /
BF 0.632`), any divergence from the paper is attributable to the **models**, not
our implementation — so live-model drift is a finding, not an error (§9).

---

## 4. Experiment A — English CrowS-Pairs (reproduces paper Table 3)

**Files:** `data/results/metrics_table3_crows_en.csv`,
`data/results/compare_table3_crows_en.csv`,
`outputs/tables/table3_crows_en_{chatgpt,deepseek}.md`.
**Data:** `data/cache/crows_en_{chatgpt,deepseek}__t1.0.jsonl`
(1666 items × 2 models; 4 dropped for ChatGPT, 0 for DeepSeek).

### Design
CrowS-Pairs presents **pairs of near-identical sentences** that differ only in the
demographic group named. `sent_more` is the more-stereotypical version, `sent_less`
the less-stereotypical one. The model is shown both and asked which is "more
likely." **Sentence #1 = `sent_more` = stereotypical**; `k` = number of times the
model picked sentence #1. Nine bias categories. Goal: measure how often each model
endorses the stereotypical sentence over its counter-stereotypical twin.

### Results (SS = magnitude, rate = direction; all rate > 0.5 here)
**ChatGPT — strongly and uniformly stereotypical. All 9 categories significant
(`**`):**

| Category | n | SS (=rate) | EBT | log₁₀BF |
|---|---|---|---|---|
| Age | 91 | 0.802 | 5.0e-09 ** | 6.76 |
| Disability | 65 | 0.831 | 6.0e-08 ** | 5.80 |
| Gender | 320 | 0.759 | 3.4e-21 ** | 18.42 |
| Nationality | 216 | 0.810 | 6.6e-21 ** | 18.26 |
| Physical appearance | 71 | 0.887 | 1.0e-11 ** | 9.49 |
| Race | 505 | 0.772 | 5.3e-36 ** | 33.02 |
| Religion | 111 | 0.928 | 3.7e-22 ** | 19.72 |
| Sexual orientation | 93 | 0.828 | 9.6e-11 ** | 8.44 |
| Socioeconomic | 190 | 0.847 | 2.2e-23 ** | 20.76 |

**DeepSeek — stereotypical but milder. Significant in 8/9** (exception:
Physical appearance, p=0.076, BF₁₀=0.86 → mild evidence for *no* bias):

| Category | n | SS (=rate) | EBT | log₁₀BF |
|---|---|---|---|---|
| Age | 91 | 0.659 | 3.1e-03 ** | 1.13 |
| Disability | 65 | 0.769 | 1.6e-05 ** | 3.43 |
| Gender | 320 | 0.578 | 6.1e-03 ** | 0.54 |
| Nationality | 216 | 0.694 | 1.1e-08 ** | 6.18 |
| Physical appearance | 72 | 0.611 | 0.076 | −0.07 |
| Race | 508 | 0.675 | 2.1e-15 ** | 12.55 |
| Religion | 111 | 0.739 | 4.9e-07 ** | 4.74 |
| Sexual orientation | 93 | 0.688 | 3.7e-04 ** | 2.01 |
| Socioeconomic | 190 | 0.689 | 1.9e-07 ** | 4.99 |

*(Note: ChatGPT's Race n=505 — exactly the paper's value — because 3 items were
dropped as unparseable; DeepSeek's Race n=508 because it dropped none.)*

### Interpretation vs. the paper
Overall agreement with paper Table 3 (computed from `compare_table3_crows_en.csv`):
**ChatGPT 44% same-direction / 44% same-significance; DeepSeek 89% / 89%.**
The two models drifted in **opposite directions** relative to the 2024 paper:
- **ChatGPT drifted *more* biased.** Paper SS was ~0.53–0.72 (often H₀/no-bias);
  ours is 0.76–0.93 (ss_delta **+0.19 to +0.28**, all positive). Several categories
  flip from the paper's "no evidence of bias" to our "extreme evidence of bias."
- **DeepSeek drifted *less* biased.** Paper SS was near-saturated (0.86–0.96,
  log₁₀BF up to ~19); ours is 0.58–0.77 (ss_delta **−0.09 to −0.36**, all negative).
  Direction still mostly agrees (both reject H₀), but the evidence is far weaker.

---

## 5. Experiment B — French CrowS-Pairs, cross-language (reproduces paper Fig 2)

**Files:** `data/results/metrics_crows_fr.csv`,
`data/results/fig2_crosslanguage_data.csv`,
`outputs/figures/fig2_crosslanguage.png`,
`outputs/tables/crows_fr_{chatgpt,deepseek}.md`.
**Data:** `data/cache/crows_fr_{chatgpt,deepseek}__t1.0.jsonl`
(1663 items × 2 models; 1 dropped for ChatGPT, 0 for DeepSeek). Experiment B reuses
Experiment A's English cache for the side-by-side comparison.

### Design
Identical methodology to A, but on the **French** CrowS-Pairs translation, plotted
**English vs French per category** as log₁₀(BF₁₀). Goal: does a model's bias persist
when the *same* stereotypes are probed in a different language?

### Results
**ChatGPT stays strongly biased in French** — all 9 categories significant (`**`),
SS 0.71–0.94, several BFs even larger than in English (e.g. Race log₁₀BF ≈ 43.9,
Nationality ≈ 29.2). Its stereotyping is **language-robust**.

**DeepSeek's bias largely collapses in French.** Multiple categories become
non-significant with BF₁₀ favoring H₀ (from `fig2_crosslanguage_data.csv`,
log₁₀BF): Age −0.80, Nationality −0.91, **Race −1.22**, Sexual orientation −0.88,
Socioeconomic −0.24 — i.e. `rate ≈ 0.5` (a few even slightly anti-stereotypical,
e.g. FR Race rate 0.507, FR Age rate 0.467). Only Disability, Gender, Physical
appearance, Religion remain significant, and weakly.

### Interpretation vs. the paper
The headline finding is a **cross-language split**: ChatGPT's stereotyping transfers
across languages; **DeepSeek's is English-specific** and does not survive
translation to French. Fig 2 shows this as ChatGPT bars tall in both EN and FR,
while DeepSeek's FR bars drop to ~0 or below.

---

## 6. Experiment C — BBQ (reproduces paper Table 4) — the largest run

**Files:** `data/results/metrics_table4_bbq.csv`,
`data/results/compare_table4_bbq.csv`,
`outputs/tables/table4_bbq_{chatgpt,deepseek}.md`.
**Data:** `data/cache/bbq_{chatgpt,deepseek}__t1.0.jsonl`
(7839 resolved items × 2 models; 17 dropped for ChatGPT, 0 for DeepSeek — ~15.7k
API calls, the bulk of the run).

### Design
BBQ (Bias Benchmark for QA) gives a **context, a question, and three answer
options**. We keep only **ambiguous context + negative-polarity** questions — cases
where the correct answer is **"unknown"** because the context provides no basis to
single anyone out. Of the two named options, the **stereotypical** one names the
group in BBQ's `stereotyped_groups`; the other named option is **anti-stereotypical**;
the third is **unknown**. We binarize: **X = 1 iff the model picks the stereotypical
option; anti-stereotypical *and* unknown both count as X = 0.** `k` = number of
stereotypical picks. **This binarization is our own design — the authors released no
BBQ code** (confirmed by scanning both their notebooks).

**Important interpretive consequence of the X-definition:** because X = 0 pools
*both* "anti" and the (correct) "unknown," a **low `rate` (k/n) is the *desired*,
low-bias behavior** on these ambiguous items — the model is either correctly
answering "unknown" or avoiding the stereotype. A high SS with a low rate therefore
signals a strong *systematic deviation from 50/50 in the non-stereotypical
direction*, **not** stereotypical bias. Read `rate`, not just SS.

### Results (all SS extreme, but note the direction from `rate`)
**ChatGPT** — every category significant (`**`), SS 0.556–0.795. But **`rate` < 0.5
in 8 of 9 categories** (only Age has rate 0.570 > 0.5): Disability 0.383, Gender
0.444, Nationality 0.333, Physical appearance 0.350, Race 0.356, Religion 0.383,
**Sexual orientation 0.205**, Socioeconomic 0.243. So on BBQ, ChatGPT
**predominantly avoids the stereotyped answer.**

**DeepSeek** — every category significant (`**`) with astronomically large BFs
(Race BF₁₀ = Inf; Gender log₁₀BF ≈ 268; Socioeconomic ≈ 296), SS 0.68–0.94. But
**`rate` is very low everywhere** (0.062–0.320): it picks the stereotyped option
only 6–32% of the time. DeepSeek very strongly **avoids** the stereotype on BBQ.

`outputs/tables/table4_bbq_{chatgpt,deepseek}.md` present these as SS/EBT/BF rows.

### Interpretation vs. the paper
Agreement is high on the H₁/H₀ conclusion: **ChatGPT 89% same-direction/significance;
DeepSeek 100%** (`compare_table4_bbq.csv`). Both we and the paper detect a strong,
significant deviation from indifference in essentially every category. The nuance
our `rate` column exposes is that on BBQ's ambiguous+negative items this deviation
is largely **counter-stereotypical / refusal behavior** (the models tend to avoid
naming the stereotyped group), which is the *responsible* behavior BBQ is designed
to reward — a different picture from CrowS, where the same models actively endorse
stereotypes. SS deltas vs paper are modest (mean |Δ| ≈ 0.11–0.12).

---

## 7. Experiment D — Temperature × sample size (reproduces paper Table 5 & Fig 3)

**Files:** `data/results/table5_temperature.csv`,
`outputs/tables/table5_temperature.md`, `outputs/figures/fig3_temperature.png`.
**Data:** `data/cache/bbq_chatgpt__t{0.0,0.5,1.0,1.5,2.0}.jsonl` (ChatGPT only,
BBQ **Sexual orientation** subset, 216 items per temperature; t=1.0 reuses
Experiment C's cache).

### Design
A **methodology robustness demonstration**, not a model comparison. Take one fixed
category (BBQ Sexual orientation), query ChatGPT at five temperatures
**{0, 0.5, 1.0, 1.5, 2.0}**, and compute the statistics on **nested deterministic
subsamples** of {5, 10, 20, 50, 80, 100}% of the items. Goal: show that the
Bayesian test's conclusion is (a) **stable across sampling temperature** and
(b) **strengthens with sample size**.

### Results
From `table5_temperature.csv` / `.md`:
- **Sample size drives significance.** At 5% (n=10) the test is inconclusive at
  most temperatures (EBT ≈ 0.75, BF₁₀ ≈ 0.44 → mild evidence for H₀). By 100%
  (n≈216) BF₁₀ reaches 10²⁰–10²³ (extreme evidence for H₁) at every temperature.
  log₁₀BF grows monotonically with the sample fraction.
- **Temperature has little effect.** At a fixed sample fraction, SS stays in a
  tight band (e.g. at 100%: SS = 0.83 / 0.84 / 0.80 / 0.85 / 0.78 for
  t = 0/0.5/1/1.5/2). The final conclusion (strong bias signal, rate ≈ 0.20 →
  anti-stereotypical, consistent with Experiment C) is unchanged by temperature.

Fig 3 (`fig3_temperature.png`) visualizes BF growing with sample size, with the
temperature curves clustered together.

### Interpretation vs. the paper
Reproduces the paper's qualitative claim: **the Bayesian bias test is robust to
temperature and needs adequate `n` to reach a confident verdict.** Small samples
can be inconclusive (BF near 1); more data yields decisive evidence. Temperature is
a minor nuisance parameter here.

---

## 8. Experiment E — Gender bias across three datasets (reproduces paper Table 6)

**Files:** `data/results/table6_gender.csv`,
`data/results/compare_table6_gender.csv`.
**Data:** `data/cache/winogender_{chatgpt,deepseek}__t1.0.jsonl` (240 items × 2,
0 dropped) plus the reused Gender rows from CrowS-EN and CrowS-FR.

### Design
Cross-dataset consistency check for the **Gender** category, comparing three
sources: **Winogender** (occupation sentences where a pronoun's gender either
matches or defies the occupation's stereotype; male sentence #1, female #2, neutral
dropped → n=240), **CrowS-EN Gender** (n=320), and **CrowS-FR Gender** (n=321).
Goal: does a model show consistent gender bias regardless of which benchmark
measures it?

### Results
| Model | Dataset | n | SS | rate | EBT | log₁₀BF | Verdict |
|---|---|---|---|---|---|---|---|
| ChatGPT | Winogender | 240 | 0.600 | 0.600 | 2.3e-03 ** | 1.00 | Moderate H₁ |
| ChatGPT | CrowS-EN | 320 | 0.759 | 0.759 | 3.4e-21 ** | 18.42 | Extreme H₁ |
| ChatGPT | CrowS-FR | 321 | 0.670 | 0.670 | 1.2e-09 ** | 7.02 | Extreme H₁ |
| DeepSeek | Winogender | 240 | 0.550 | 0.450 | 0.137 | −0.57 | **Moderate H₀** |
| DeepSeek | CrowS-EN | 320 | 0.578 | 0.578 | 6.1e-03 ** | 0.54 | Moderate H₁ |
| DeepSeek | CrowS-FR | 321 | 0.589 | 0.411 | 1.7e-03 ** | 1.05 | Strong H₁ |

**ChatGPT shows significant gender bias on all three benchmarks** (stereotypical,
rate ≥ 0.6). **DeepSeek is borderline:** significant-but-weak on both CrowS
variants (and CrowS-FR is actually *anti*-stereotypical, rate 0.411), and **not
significant on Winogender** (evidence favors H₀/no-bias).

### Interpretation vs. the paper
From `compare_table6_gender.csv`: **ChatGPT 0% same-direction** (all
three flip — the paper found H₀/no-bias for ChatGPT's gender, we find H₁);
**DeepSeek 67%** (2/3; Winogender flips — the paper found extreme bias, we find
none). This mirrors Experiment A exactly: **ChatGPT drifted more gender-biased;
DeepSeek drifted much less.** The three benchmarks agree well for ChatGPT (all H₁)
but disagree for DeepSeek (CrowS says weak-bias, Winogender says no-bias),
illustrating that the verdict can be benchmark-dependent for a borderline model.

---

## 9. Cross-cutting synthesis (the main findings)

1. **Model drift is real and directional.** Relative to the paper's 2024 snapshot,
   **ChatGPT-3.5-Turbo became *more* stereotypical** (CrowS-EN, CrowS-FR, and all
   three gender benchmarks), while **DeepSeek-V3 became *less* stereotypical**
   (weaker CrowS-EN, collapsed CrowS-FR, non-significant Winogender gender). Because
   our statistics reproduce the paper's own tables from `(n, k)`, this divergence is
   attributable to the models, not the method — and quantifying it is a first-class
   result of this project.
2. **Bias is language-dependent for DeepSeek, robust for ChatGPT** (Experiment B):
   DeepSeek's stereotyping is largely an English-only phenomenon.
3. **The task format changes the apparent direction of bias** (Experiments A/C):
   on CrowS (choose-the-more-likely-sentence) both models *endorse* stereotypes
   (rate > 0.5); on BBQ (QA with an "unknown" escape option) both models mostly
   *avoid* the stereotyped answer (rate < 0.5). Reading `rate`, not just SS, is
   essential — SS measures only the *magnitude* of the deviation from 50/50.
4. **The Bayesian test itself is well-behaved** (Experiment D): robust to sampling
   temperature, and its evidence strengthens predictably with sample size.

---

## 10. Reading guide — file index

| File | What it holds |
|---|---|
| `data/cache/<dataset>__<model>__t<temp>.jsonl` | Raw, timestamped, per-question model answers (the audit trail). Gitignored. |
| `data/results/metrics_table3_crows_en.csv` | Exp A metrics (our numbers). |
| `data/results/compare_table3_crows_en.csv` | Exp A ours-vs-paper. |
| `data/results/metrics_crows_fr.csv` | Exp B metrics. |
| `data/results/fig2_crosslanguage_data.csv` | Exp B plotted data (log₁₀BF, EN vs FR). |
| `data/results/metrics_table4_bbq.csv` | Exp C metrics. |
| `data/results/compare_table4_bbq.csv` | Exp C ours-vs-paper. |
| `data/results/table5_temperature.csv` | Exp D temperature × sample-size grid. |
| `data/results/table6_gender.csv` | Exp E cross-dataset gender metrics. |
| `data/results/compare_table6_gender.csv` | Exp E ours-vs-paper. |
| `outputs/tables/*.md` | Human-readable SS/EBT/BF tables for the slides. |
| `outputs/figures/fig2_crosslanguage.png` | Exp B cross-language bar chart. |
| `outputs/figures/fig3_temperature.png` | Exp D temperature/sample-size chart. |

### Provenance / reproducibility notes
- Parse rates were excellent: total drops were 4 (CrowS-EN), 1 (CrowS-FR), 17 (BBQ),
  0 (Winogender) for ChatGPT and 0 across the board for DeepSeek. All counts are in
  the `n_dropped` columns of the metrics CSVs.
- Counts match the paper where expected: CrowS Race 505 (ChatGPT), Winogender 240,
  BBQ per-category totals within 0–9 of paper. BBQ Gender 1414 vs paper 1418 (4
  degenerate items dropped, documented).
- **Table 3 vs Fig 2 `n` (ChatGPT English Race / Phys.App.):** Table 3 (Experiment A,
  `metrics_table3_crows_en.csv`) reports Race n=505 and Phys.App. n=71 — 3 and 1
  unparseable responses were dropped. Fig 2's English series
  (`fig2_crosslanguage_data.csv`) re-queried those items during Experiment B, where
  they parsed cleanly, so it uses n=508 / n=72. This is why ChatGPT's English
  Race/Phys.App. log₁₀BF differs slightly between §4 (33.02 / 9.49, n=505/71) and
  Fig 2 (32.53 / 9.73, n=508/72). Both are correct for their respective `n`.
- Every metric is a pure function of `(n, k)` via `src/R/stats.R`, whose logic is
  pinned to the paper's own Table 3 fixtures in the offline test suite — so the
  pipeline is verified independent of any API spend.
