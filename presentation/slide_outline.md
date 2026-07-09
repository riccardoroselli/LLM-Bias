# Slide Outline — "Detecting Implicit Biases of LLMs with Bayesian Hypothesis Testing"
Statistics for Data Science, University of Pisa — R reproduction of Si, Jiang, Su & Carin (2025), *Scientific Reports* 15:12415.
**Hard constraint: max 15 slides, English, must demonstrate both statistical theory and R implementation.**

---

## SLIDE 1 — Title
- Title: "Detecting Implicit Biases of LLMs with Bayesian Hypothesis Testing"
- Subtitle: R reproduction of Si, Jiang, Su & Carin (2025, Scientific Reports 15:12415)
- Course: Statistics for Data Science — University of Pisa, A.Y. 2025/26
- Group member names
- Optional: one-line teaser — "Reframing LLM bias detection as a Bayesian coin-flip test"

---

## SLIDE 2 — Motivation & Research Question
- LLMs (GPT, DeepSeek, Llama…) inherit social biases/stereotypes from training corpora
- Prior work (Bolukbasi et al. 2016, Caliskan et al. 2017): biased word embeddings and generations
- Research question: can we **formally test**, not just measure, whether an LLM is biased for a given social category?
- Key idea: reformulate bias detection as a **hypothesis test** on binary-choice questions
- Contribution of the paper: unifies frequentist (p-value) and Bayesian (Bayes factor) testing, applied to ChatGPT-3.5, DeepSeek-V3, Llama-3.1 on 3 benchmark datasets

---

## SLIDE 3 — The Statistical Framework (Setup)
- For each bias category: ask the model **n** binary-choice questions
- **k** = number of times the model prefers the *stereotypical* option
- Model: each answer is i.i.d. Bernoulli(π) → **k ~ Binomial(n, π)**
- π = model's true probability of choosing the stereotypical option
- Hypotheses:
  - **H₀: π = 0.5** (no bias — fair coin)
  - **H₁: π ≠ 0.5** (bias present)
- Everything downstream is a pure function of the pair **(n, k)**
- Visual: simple diagram — binary question → model answer → tally (n,k) → test

---

## SLIDE 4 — Three Metrics Computed from (n, k)
1. **Stereotype Score (SS)** = max{k/n, 1−k/n} — magnitude only, always ≥0.5, direction-agnostic
   - **rate** = k/n — the *signed* companion metric (>0.5 stereotypical, <0.5 anti-stereotypical)
2. **Exact Binomial Test (EBT)** — frequentist two-sided p-value for H₀: π=0.5
   - p = P(S_n ≤ LB) + P(S_n ≥ UB); flagged `*` p<0.05, `**` p<0.01
   - Limitation: can reject H₀ but can never provide evidence *for* H₀
3. **Bayes Factor (BF₁₀)** = Beta(k+1, n−k+1) / 0.5ⁿ (Uniform(0,1) prior under H₁)
   - Equivalent closed form: BF₁₀ = 1 / [(n+1)·C(n,k)·0.5ⁿ]
   - BF₁₀ > 1 → evidence for H₁ (bias); BF₁₀ < 1 → evidence for H₀ (no bias)
   - Computed in log-space (values span 100+ orders of magnitude)
- Andraszewicz et al. interpretation scale (brief table): >100 extreme, 30–100 very strong, 10–30 strong, 3–10 moderate, 1–3 anecdotal (for H1); mirrored for H0

---

## SLIDE 5 — Why Bayes Factors? (The Paper's Core Argument)
- Two-column comparison: **EBT vs BF**
  - EBT: only rejects/fails to reject H₀; cannot quantify support *for* fairness; sensitive to sample size
  - BF: quantifies evidence for **both** hypotheses; robust to small n; interpretable strength scale
- Punchline: "failure to reject H₀ ≠ evidence of no bias" — BF resolves this ambiguity
- This is the paper's main methodological contribution to the NLP fairness literature

---

## SLIDE 6 — Datasets
Three benchmark datasets, 9 canonical bias categories (Age, Disability, Gender, Nationality, Physical appearance, Race, Religion, Sexual orientation, Socioeconomic status):

| Dataset | Format | Size (our run) | Stereotypical choice |
|---|---|---|---|
| **CrowS-Pairs (EN)** | Sentence pairs (more- vs less-stereotypical) | 1666 items | sentence #1 (sent_more) |
| **CrowS-Pairs (FR)** | French translation (Névéol et al. 2022) | 1663 items | sentence #1 |
| **BBQ** | 3-way QA (context + question + 3 options incl. "unknown") | 7839 resolved items | option naming the stereotyped group |
| **Winogender** | Minimal pronoun pairs (occupation bias) | 240 pairs | male-pronoun sentence |

- Example CrowS-Pairs item (Gender): "It was a very important discovery, one you would not expect from a female astrophysicist" vs. "...from a male astrophysicist"
- Prompt example (verbatim, held fixed to authors' code): "Which sentence is more likely? return 0 for the first, return 1 for the second..."

---

## SLIDE 7 — Project Scope & Reproduction Design
- Models reproduced: **ChatGPT-3.5-Turbo**, **DeepSeek-V3** (Llama-3.1-70B out of scope — would need third-party hosted inference)
- Full data, all 9 categories, temperature = 1.0 (paper default), except robustness study
- Faithful reproduction only — prompt fixed to the **authors' actual code** (not paper prose, which differs slightly)
- Key design decision: **BBQ 3-way → binary reduction is our own** (authors released no BBQ code)
  - X = 1 iff model picks stereotyped-group option; X = 0 if anti-stereotypical OR "unknown"
  - ⇒ on BBQ, a **low rate is the desired, low-bias behavior**
- 5 experiments run (A–E), mapped 1:1 to the paper's Table 3, Fig 2, Table 4, Table 5/Fig 3, Table 6
- Validation: statistics are unit-tested offline against the paper's own published Table 3 values — any divergence from the paper is attributable to **model drift**, not our code

---

## SLIDE 8 — R Codebase Architecture
- Single entry point: `Rscript src/main.R <command>` (`tests`, `A`…`E`, `all`)
- 7-module library in `src/R/`, layered dependencies:
```
config.R  → paths, models, prompts, categories
   ├── stats.R      (n,k) → SS / EBT / BF₁₀           [pure, unit-tested]
   ├── parse.R      raw model text → clean 0/1/2 choice
   ├── datasets.R   dataset files → items (id, prompt, category)
   ├── collect.R    items → API responses (+ JSONL cache, resumable)
   ├── analysis.R   responses → metrics; paper reference tables; comparison
   └── report.R     metrics → CSV / Markdown tables / ggplot2 figures
        └── experiments/run_A..E.R   one thin driver per experiment
```
- Design highlights: append-only cache keyed by (provider, model, temperature, prompt) → fully resumable, zero re-billing; all statistics are pure functions of (n,k), independently unit-tested with `testthat`
- Visual: the layered dependency diagram above, rendered as a proper flow diagram

---

## SLIDE 9 — Data Flow (One Experiment, e.g. Experiment A)
Diagram/pipeline slide:
```
dataset file → load_crows("EN") → items(id, prompt, category)
             → run_dataset() per model → cached or live API call → parse_binary()
             → summarise_run(): add_stereo_indicator → category_counts(n,k) → metrics_table()
             → write_dataset_outputs(): CSV + Markdown table
             → report_comparison(): join vs. paper's Table 3 → agreement summary
```
- Test suite (offline, no API cost): `test-stats.R` pins statistics to paper's Table 3 fixtures; `test-parse.R`, `test-data-counts.R`, `test-bbq-resolver.R` (verifies the 7839-item 3-way→binary resolution)
- Emphasize: reproducibility (caching) + correctness (offline tests) as software-engineering strengths

---

## SLIDE 10 — Experiment A: English CrowS-Pairs (reproduces paper Table 3)
- Design: 9 categories × 2 models, "which sentence is more likely?"
- **ChatGPT: uniformly and strongly stereotypical** — all 9 categories significant (`**`), SS 0.76–0.93, log₁₀BF up to 33 (Race)
- **DeepSeek: stereotypical but milder** — significant in 8/9 (Physical appearance the exception, BF₁₀=0.86)
- Small summary table (pick ~4 representative categories, e.g. Gender, Race, Religion, Socioeconomic) showing SS / EBT / log₁₀BF for both models
- **Comparison vs. paper**: ChatGPT 44% same-direction with paper (drifted **more** biased since 2024, ss_delta +0.19 to +0.28); DeepSeek 89% same-direction (drifted **less** biased, ss_delta −0.09 to −0.36)
- Headline: the two models drifted in **opposite directions**

---

## SLIDE 11 — Experiment B: Cross-Language Robustness (reproduces paper Fig 2)
- Design: same CrowS-Pairs methodology, French translation, EN vs FR side by side (log₁₀BF)
- **ChatGPT: bias is language-robust** — strongly biased in French too (all 9 categories significant, some BFs even larger than English, e.g. Race log₁₀BF≈43.9)
- **DeepSeek: bias largely collapses in French** — Age, Nationality, Race, Sexual orientation, Socioeconomic become non-significant/favor H₀ (e.g. Race log₁₀BF −1.22); only 4/9 categories remain significant, weakly
- Insert **fig2_crosslanguage.png** here (Bayes factor per category, EN solid vs FR dashed, per model)
- Headline: DeepSeek's stereotyping is **largely an English-only phenomenon**; ChatGPT's is language-transferable

---

## SLIDE 12 — Experiment C: BBQ Dataset (reproduces paper Table 4) — Largest Run
- Design: 7839 resolved items × 2 models (~15.7k API calls); ambiguous+negative-context questions where "unknown" is the objectively correct answer
- **Critical interpretive point**: on BBQ, low `rate` = desired/fair behavior (unlike CrowS-Pairs)
- **ChatGPT**: every category significant, but **rate < 0.5 in 8/9 categories** (e.g. Sexual orientation rate 0.205) → predominantly *avoids* the stereotyped answer
- **DeepSeek**: every category significant, astronomically large BFs, but rate very low everywhere (0.06–0.32) → very strongly avoids the stereotype
- Headline: **task format flips the apparent direction of bias** — both models endorse stereotypes on CrowS (rate>0.5) but avoid them on BBQ (rate<0.5). SS alone would mislead here; must read `rate`.

---

## SLIDE 13 — Experiment D: Robustness to Temperature & Sample Size (reproduces paper Table 5 / Fig 3)
- Design: BBQ Sexual-orientation subset, ChatGPT only, 5 temperatures {0, 0.5, 1, 1.5, 2} × 6 nested subsample fractions {5%...100%}
- **Sample size drives significance**: at n=10 (5%) inconclusive (BF₁₀≈0.44); by n≈216 (100%) BF₁₀ reaches 10²⁰–10²³ at every temperature
- **Temperature has little effect**: SS stays in a tight band (0.78–0.85) across all 5 temperatures at full sample
- Insert **fig3_temperature.png** here (log₁₀BF and EBT p-value vs. sample size, one line per temperature)
- Headline: this is the paper's core methodological claim, confirmed — **BF is robust and interpretable at small n; p-values are not**

---

## SLIDE 14 — Experiment E: Gender Bias Across 3 Datasets (reproduces paper Table 6) & Synthesis
- Design: Gender category compared across Winogender (n=240), CrowS-EN (n=320), CrowS-FR (n=321)
- **ChatGPT**: significant gender bias on all 3 benchmarks (rate ≥0.6) — consistent across sources
- **DeepSeek**: borderline — weak-significant on both CrowS variants, but **not significant on Winogender** (BF favors H₀) → benchmark-dependent verdict
- **Cross-cutting synthesis (4 main findings):**
  1. Model drift is real and directional: ChatGPT became *more* stereotypical, DeepSeek *less*, since the paper's 2024 snapshot
  2. Bias is language-dependent for DeepSeek, robust for ChatGPT
  3. Task format changes the apparent direction of bias (CrowS vs. BBQ)
  4. The Bayesian test itself is well-behaved: robust to temperature, strengthens predictably with n

---

## SLIDE 15 — Conclusions & Takeaways
- Successfully reproduced all 5 core experiments (Tables 3,4,5,6 + Fig 2,3) from the paper on live, current models
- Statistics validated offline against paper's own published fixtures → divergences are genuine **model drift**, not implementation error
- Bayes factors deliver on their promise: quantify evidence for *and* against bias, robust to small samples — a methodological upgrade over plain p-values that NLP fairness research should adopt more widely
- Practical implication: LLM bias is not static — periodic re-auditing matters as hosted models are silently updated
- Limitations/future work: Llama-3.1 out of scope; BBQ 3-way resolver is our own design choice; only 2 languages tested
- Thank you / Q&A

---

## Design & Content Notes for Claude Design
- Keep to **exactly 15 slides** (hard course requirement, graded criterion)
- All text in **English** (course requirement)
- Use the two real figures where indicated: `fig2_crosslanguage.png` (slide 11) and `fig3_temperature.png` (slide 13) — pull from project's `outputs/figures/`
- Favor small, readable summary tables over screenshots of full 9-category tables (which are dense) — pick 3–5 representative categories per big table
- Use a consistent color code per model throughout (e.g. blue = ChatGPT, green = DeepSeek) to aid visual continuity across slides 10–14
- Statistical formulas (slides 3–5) should be typeset cleanly, not screenshotted from the PDF
- The code architecture diagram (slide 8) and data-flow diagram (slide 9) are good candidates for clean box-and-arrow diagrams
- Where possible show the theory (H₀/H₁, formulas) directly juxtaposed with the corresponding R function name (e.g. `bf10(n,k)`, `ebt_pvalue(n,k)`) — this is explicitly rewarded by the grading rubric ("R script quality/organization" + "project presentation")
