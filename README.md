# LLM-Bias — Bayesian hypothesis testing for LLM bias detection

R reproduction of **Si, Jiang, Su & Carin (2025), *"Detecting implicit biases of
large language models with Bayesian hypothesis testing"*** (Scientific Reports
15:12415). Course project for *Statistics for Data Science*, University of Pisa,
A.Y. 2025/26.

## The idea

The paper reframes bias detection as a hypothesis test. For each bias category a
model answers `n` binary questions; `k` counts how often it prefers the
**stereotypical** option. Modelling `k ~ Binomial(n, π)`, it tests

- **H₀: π = 0.5** (no bias) against **H₁: π ≠ 0.5** (bias),

through two lenses: an **exact binomial test** (a frequentist p-value) and a
**Bayes factor** `BF₁₀ = Beta(k+1, n−k+1) / 0.5ⁿ` (Uniform(0,1) prior). Unlike a
p-value, the Bayes factor can also quantify evidence *for* the no-bias
hypothesis.

## Status

**Reproduction complete.** All five experiments have been run on live models.
Metrics and our-vs-paper comparisons are in `data/results/`; figures and tables
in `outputs/`. See **[`ExperimentResults.md`](ExperimentResults.md)** for the full
results and interpretation.

## Scope

| | |
|---|---|
| **Models** | ChatGPT-3.5-Turbo, DeepSeek-V3 (the paper's third model, Llama-3.1-70B, is out of scope) |
| **Datasets** | CrowS-Pairs (EN & FR), BBQ, Winogender — full data, all nine bias categories |
| **Experiments** | Table 3 (CrowS-EN) · Fig 2 (EN vs FR) · Table 4 (BBQ) · Table 5 + Fig 3 (temperature × sample size) · Table 6 (gender across datasets) |

An **our-numbers vs the paper's-numbers** comparison is built in. Because the
hosted models have drifted since the paper's 2024 data collection, that
divergence is itself a finding: ChatGPT now reads as *more* stereotypical and
DeepSeek *less*, and DeepSeek's bias is largely English-only.

## Getting started

```
Rscript src/main.R tests        # offline correctness suite — no API, no cost
Rscript src/main.R              # list all commands
Rscript src/main.R all          # reproduce every experiment (cached + resumable)
```

Requirements, `.env` API-key setup, and the code layout are in
**[`src/README.md`](src/README.md)**.

## Layout

```
paper/         the paper (full text)
src-origin/    the authors' original notebooks (read-only reference)
data/          input datasets + response cache + result CSVs   → data/README.md
src/           the R implementation                            → src/README.md
outputs/       generated figures and tables                    → outputs/README.md
presentation/  the ≤15-slide English deck (in progress)
```
