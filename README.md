# LLM-Bias: Bayesian hypothesis testing for LLM bias detection

An R implementation that reproduces Si, Jiang, Su & Carin (2025), "Detecting
implicit biases of large language models with Bayesian hypothesis testing".

## The idea

The paper turns bias detection into a hypothesis test. For each bias category
(age, gender, race, and so on), a model answers `n` paired questions built so
one answer is the "stereotypical" choice; `k` counts how often it picks that
one. Modeling `k` as Binomial(n, π), the test pits **H₀: π = 0.5** (no bias)
against **H₁: π ≠ 0.5** (the model favors one answer), using two tools: an
exact binomial test (a p-value), and a Bayes factor, BF₁₀ = Beta(k+1, n−k+1) /
0.5ⁿ, under a uniform prior on π. The Bayes factor's edge over the p-value is
that it can quantify evidence for the no-bias hypothesis too, not just fail to
reject it.

## Scope

| | |
|---|---|
| **Models** | ChatGPT-3.5-Turbo, DeepSeek-V3 |
| **Datasets** | CrowS-Pairs (EN & FR), BBQ, Winogender, full data, all nine bias categories |
| **Experiments** | Table 3 (CrowS-EN) · Fig 2 (EN vs FR) · Table 4 (BBQ) · Table 5 + Fig 3 (temperature × sample size) · Table 6 (gender across datasets) |

## Layout

```
paper/          the original paper (PDF)
data/           input datasets + response cache + result CSVs   → data/README.md
src/            the R implementation                            → src/README.md
  R/            the 7-module library (stats, parsing, datasets, collection, analysis, report)
  experiments/  one script per experiment (run_A..E.R), run_all.R, shared helpers
  tests/        offline testthat suite — stats, parsing, dataset counts, BBQ resolver
outputs/        generated figures and tables                    → outputs/README.md
presentation/   the slide deck (LLM Bias Deck.pdf)
```

## Results

All five experiments ran against live models, ChatGPT-3.5-Turbo and
DeepSeek-V3, across CrowS-Pairs (English and French), BBQ, and Winogender, all
nine of the paper's bias categories, no subsampling.

Both models still show measurable stereotyping, but the details shifted since
the paper's 2024 snapshot, and they shifted in opposite directions. ChatGPT is
now more stereotypical, while DeepSeek is now less stereotypical.

<center><img src="outputs/figures/fig2_crosslanguage.png" width="60%" alt="Cross-language bias comparison (EN vs FR)"></center>

*Log₁₀ Bayes factor per bias category, English vs French: ChatGPT's stereotyping holds in both languages, DeepSeek's mostly vanishes in French.*

Concretely: on English CrowS-Pairs, ChatGPT is now significantly stereotypical in
all 9/9 categories (SS 0.76–0.93, e.g. Religion SS=0.93, log₁₀BF=19.7 — up from the
paper's SS ≈0.53–0.72), while DeepSeek is significant in 8/9 (SS 0.58–0.77, down
from the paper's 0.86–0.96) and its bias mostly evaporates in French — e.g. Race
log₁₀BF drops from +12.6 in English to −1.2 in French, flipping the evidence to
favor no bias. On gender specifically (Table 6), ChatGPT is significantly biased
across all three benchmarks (rate 0.60–0.76), while DeepSeek shows no significant
gender bias at all on Winogender (rate 0.45, log₁₀BF −0.57, evidence for H₀).

## Getting started

Run from the project root:

```
Rscript src/main.R tests        # offline correctness suite — no API, no cost
Rscript src/main.R              # print usage
Rscript src/main.R all          # reproduce every experiment (cached + resumable)
```

Requirements, `.env` API-key setup, and the code layout are in
**[`src/README.md`](src/README.md)**.

## Documentation

Two more folder-level `README.md` files round things out:
[`data/README.md`](data/README.md) covers dataset provenance, the cache
format, and result files; [`outputs/README.md`](outputs/README.md) covers the
generated tables and figures. See [`src/README.md`](src/README.md) above for
how to run the code.
