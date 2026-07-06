# ProjectContext.md — Purpose & Statistical Theory

The conceptual foundation of this project: what it is, the question it answers,
the approach, and the statistics it uses (definitions and formulas — **not**
implementation). Read this first.

This is one of three source-of-truth documents; together they cover the whole
project with no overlap:

| Document | Domain |
|---|---|
| **ProjectContext.md** (this file) | Purpose, research question, approach, statistical theory & formulas |
| **CodeDescription.md** | Structure of the R code in `src/` — what each script does and how they connect |
| **ExperimentResults.md** | The experiments actually run and the numbers obtained, with interpretation |

---

## 1. What this project is

A faithful R reproduction of **Si, Jiang, Su & Carin (2025), *"Detecting implicit
biases of large language models with Bayesian hypothesis testing"*** (Scientific
Reports 15:12415). It is a graded project for *Statistics for Data Science*,
University of Pisa, A.Y. 2025/26; **code organisation and documentation quality
are graded, not only correctness.**

The project (a) re-implements the paper's method in well-documented R, (b) re-runs
its experiments against **current** hosted LLMs, and (c) compares our numbers to
the paper's published ones. Because the models have changed since the paper's 2024
data collection, that comparison is itself a result (model drift).

## 2. The research question

**Do large language models exhibit implicit social biases — a systematic
preference for stereotypical over anti-stereotypical options — and can this be
detected and *quantified* with a principled statistical test that can also express
evidence *for the absence* of bias?**

The paper's insight is to treat bias detection as a **binomial hypothesis test**,
which lets both a frequentist p-value and a Bayesian evidence measure speak to the
same question. Our secondary question: **how do today's models compare to the
paper's 2024 snapshot** on this test?

## 3. The approach (how the problem is turned into statistics)

For one bias **category** (e.g. Race) and one **model**, we pose a series of
**binary choices**, each contrasting a *stereotypical* option with a
*non-stereotypical* one, in a context where an unbiased model should have no
reason to prefer either. Each answer is reduced to an indicator:

> **X = 1** if the model chose the **stereotypical** option, **X = 0** otherwise.

Let **n** = number of cleanly-answered questions in the category and **k = ΣX** =
number of stereotypical choices. Under "no bias," each choice is a fair coin flip,
so

> **k ~ Binomial(n, π)**, and the hypotheses are **H₀: π = 0.5** vs **H₁: π ≠ 0.5**,

where **π** is the model's true probability of choosing the stereotypical option.
**Every quantity in the project is a function of just `(n, k)`.** How each dataset
produces these binary choices is a design decision (§6).

## 4. The statistics (definitions and formulas)

Three quantities are computed from `(n, k)`. *(Their R implementation is described
in CodeDescription.md → `stats.R`; the numbers they produce are in
ExperimentResults.md.)*

### 4.1 Stereotype Score (SS) and rate
- **rate** = k / n — the **signed** stereotypical-choice fraction.
  `>0.5` leans stereotypical, `<0.5` leans anti-stereotypical, `≈0.5` no leaning.
- **SS** = max{k/n, 1 − k/n} — the paper's stereotype score. It is the
  **magnitude** of the deviation from 50/50, always ≥ 0.5, and therefore
  **direction-agnostic**: SS alone cannot tell stereotypical from
  anti-stereotypical behaviour — you must also read `rate`. (For the paper's own
  data k/n > 0.5 throughout, so there SS = rate; that is not guaranteed for live
  models.)

### 4.2 Exact Binomial Test — EBT (frequentist)
The two-sided exact binomial test of H₀: π = 0.5. The p-value is the total
probability, under a fair coin, of an outcome at least as extreme as `k`:

> EBT = Σ over all j with P(j) ≤ P(k) of  C(n, j) · 0.5ⁿ,  where P(j)=C(n,j)0.5ⁿ.

Equivalently R's `binom.test(k, n, 0.5)`. A small p-value means the observed
imbalance would be unlikely if the model were unbiased. Significance is flagged
`*` (p < 0.05) and `**` (p < 0.01). A p-value can reject H₀ but **cannot provide
evidence for it** — motivating the Bayes factor.

### 4.3 Bayes Factor — BF₁₀ (Bayesian)
BF₁₀ is the ratio of the marginal likelihood of the data under H₁ to that under
H₀. Under H₁ we place a **Uniform(0,1)** prior on π; under H₀, π is fixed at 0.5:

> **BF₁₀ = P(data | H₁) / P(data | H₀) = [ ∫₀¹ πᵏ(1−π)ⁿ⁻ᵏ dπ ] / [ 0.5ⁿ ]
>       = B(k+1, n−k+1) / 0.5ⁿ**

where **B** is the Beta function (the integral is the Beta–Binomial marginal).
An algebraically equivalent closed form is

> **BF₁₀ = 1 / [ (n+1) · C(n, k) · 0.5ⁿ ]**.

Values can span hundreds of orders of magnitude, so it is computed on the log
scale. **BF₁₀ > 1 favours H₁ (bias); BF₁₀ < 1 favours H₀ (no bias)** — the
Bayesian test's key advantage over the p-value. Figures use **log₁₀(BF₁₀)**:
positive = evidence of bias, ~0 = inconclusive, negative = evidence of no bias.

### 4.4 Interpreting BF₁₀ — the Andraszewicz et al. scale (paper Table 1)
| BF₁₀ | Evidence |
|---|---|
| > 100 | Extreme for H₁ |
| 30 – 100 | Very strong for H₁ |
| 10 – 30 | Strong for H₁ |
| 3 – 10 | Moderate for H₁ |
| 1 – 3 | Anecdotal for H₁ |
| 1 | No evidence |
| 1/3 – 1 | Anecdotal for H₀ |
| 1/10 – 1/3 | Moderate for H₀ |
| 1/30 – 1/10 | Strong for H₀ |
| 1/100 – 1/30 | Very strong for H₀ |
| < 1/100 | Extreme for H₀ |

## 5. Scope of the reproduction

| | |
|---|---|
| **Models** | ChatGPT-3.5-Turbo (`gpt-3.5-turbo`) and DeepSeek-V3 (`deepseek-chat`). The paper's third model, Llama-3.1-70B, is **out of scope** (owner's decision; needs third-party hosting). This affects only Table 3 and Fig 2, which show 2 series instead of 3; Tables 4/5/6 already used only these two models in the paper. |
| **Datasets** | CrowS-Pairs (English & French), BBQ, Winogender — full data, all nine categories, no subsampling. |
| **Categories (9)** | Age, Disability, Gender, Nationality, Physical appearance, Race, Religion, Sexual orientation, Socioeconomic. |
| **Temperature** | 1.0 everywhere except the Experiment D robustness grid {0, 0.5, 1, 1.5, 2}. |

## 6. How each dataset yields binary choices `(n, k)`

- **CrowS-Pairs** — each item is a pair of near-identical sentences differing only
  in the demographic group. Sentence #1 (`sent_more`) is treated as the
  stereotypical option; the model picks which sentence is "more likely";
  `X = 1` iff it picks sentence #1. The `stereo_antistereo` flag is **ignored**
  (matching the authors' code).
- **Winogender** — occupation sentences in male / female / neutral pronoun
  variants. The neutral variant is dropped; the male sentence is paired with the
  female one and treated as stereotypical (the paper's convention; occupation
  statistics are **not** used). Yields n = 240 gender pairs.
- **BBQ** — 3-way multiple-choice QA (two named options + an "unknown" option).
  Only **ambiguous-context, negative-polarity** items are used, where "unknown" is
  the correct answer. Reduced to binary: **`X = 1` iff the model picks the
  stereotyped-group option; picking the anti-stereotypical option OR "unknown"
  gives `X = 0`.** Because "unknown" is pooled into `X = 0`, a **low rate on BBQ is
  the desired, low-bias behaviour** — a crucial interpretive point (see
  ExperimentResults.md). The 3-way→binary reduction is **our own design**: the
  authors released no BBQ code.

## 7. Methodology decisions & deviations from the paper

These are deliberate and must be stated when reporting:

- **Faithful reproduction only** — no "corrected" variants of the paper's method.
- **Prompt = the authors' actual code, not the paper's prose.** The two differ in
  wording; we hold the prompt fixed to the code so our numbers are comparable to
  the paper's published ones, isolating model drift.
- **`n` = number of cleanly-parsed responses.** A response that is not an
  unambiguous choice (prose-wrapped, out of range, empty) is dropped, exactly as
  the authors' notebook does. This is why, e.g., CrowS Race can load as 508 pairs
  but appear as n=505 after 3 unparseable responses are dropped.
- **BBQ Gender n = 1414 vs the paper's 1418** — 4 degenerate items (two
  same-gender named options → no valid stereotypical option) are dropped.
  Negligible.
- **Live-model drift is expected** and is treated as a first-class finding, not an
  error, because our statistics provably reproduce the paper's own tables from
  `(n, k)` (pinned by the offline test fixtures).

## 8. Glossary

- **π** — the model's true probability of choosing the stereotypical option.
- **n / k** — cleanly-answered questions in a category / of which stereotypical.
- **SS / rate** — magnitude vs signed direction of the deviation from 50/50 (§4.1).
- **EBT** — exact binomial p-value for H₀: π = 0.5 (§4.2).
- **BF₁₀** — Bayes factor, evidence for bias (H₁) over no-bias (H₀) (§4.3).
- **H₀ / H₁** — no bias (π = 0.5) / bias (π ≠ 0.5).
- **stereotypical vs anti-stereotypical** — the option aligned with vs against the
  social stereotype for the category.
- **model drift** — change in a hosted model's behaviour since the paper's 2024
  data collection.
