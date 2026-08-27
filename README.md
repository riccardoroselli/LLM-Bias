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

## What we found

All five experiments ran against live models, ChatGPT-3.5-Turbo and
DeepSeek-V3, across CrowS-Pairs (English and French), BBQ, and Winogender, all
nine of the paper's bias categories, no subsampling.

Both models still show measurable stereotyping, but the details shifted since
the paper's 2024 snapshot, and they shifted in opposite directions. ChatGPT is
now more stereotypical: on English CrowS-Pairs it shows significant bias in
all nine categories, several of which the paper had scored as no evidence of
bias at all. DeepSeek is now less stereotypical. What's left of its bias
barely survives translation, either: the same sentences in French push most
of its significant categories back toward chance.

Question format matters too. CrowS-Pairs asks the model to pick the more
likely sentence, and both models lean toward the stereotype. BBQ offers a
third "unknown" option, and both models mostly take it instead of the
stereotyped answer. A temperature × sample-size sweep (Experiment D) shows the
Bayes factor behaving the way the theory predicts: stable across sampling
temperature, with its evidence strengthening steadily as the sample grows.

## Scope

| | |
|---|---|
| **Models** | ChatGPT-3.5-Turbo, DeepSeek-V3 (the paper's third model, Llama-3.1-70B, is out of scope) |
| **Datasets** | CrowS-Pairs (EN & FR), BBQ, Winogender, full data, all nine bias categories |
| **Experiments** | Table 3 (CrowS-EN) · Fig 2 (EN vs FR) · Table 4 (BBQ) · Table 5 + Fig 3 (temperature × sample size) · Table 6 (gender across datasets) |

A side-by-side comparison against the paper's published numbers is built into
every experiment; that's where the findings above come from.

## Layout

```
paper/          the original paper (PDF)
data/           input datasets + response cache + result CSVs   → data/README.md
src/            the R implementation                            → src/README.md
outputs/        generated figures and tables                    → outputs/README.md
presentation/   the slide deck (LLM Bias Deck.pdf)
```

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
