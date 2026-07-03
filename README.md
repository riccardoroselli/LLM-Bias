# LLM-Bias — Bayesian hypothesis testing for LLM bias detection

R reproduction of **Si, Jiang, Su & Carin (2025), *"Detecting implicit biases of
large language models with Bayesian hypothesis testing"*** (Scientific Reports
15:12415), for the course *Statistics for Data Science* (University of Pisa,
A.Y. 2025/26).

The paper reformulates LLM bias detection as a hypothesis test: for each bias
category it records whether a model prefers the *stereotypical* option in a
series of binary-choice questions, models the counts as `Binomial(n, π)`, and
tests `H0: π = 0.5` with both an **exact binomial test** and a **Bayes factor**
(Uniform(0,1) prior; closed form `BF10 = Beta(k+1, n−k+1) / 0.5ⁿ`). The Bayes
factor's advantage is that it can quantify evidence *for* the no-bias hypothesis.

## Scope of this reproduction

- **Models:** ChatGPT‑3.5‑Turbo and DeepSeek‑V3 (the paper's third model,
  Llama‑3.1‑70B, is out of scope).
- **Datasets:** CrowS‑Pairs (EN & FR), BBQ, Winogender — full data, all nine
  bias categories.
- **Experiments reproduced:** Table 3 (CrowS‑EN), Fig 2 (EN vs FR), Table 4
  (BBQ), Table 5 + Fig 3 (temperature × sample size), Table 6 (gender across
  three datasets) — plus a first-class **our-numbers vs the paper's-numbers**
  comparison.

## Getting started

See **[`src/README_src.md`](src/README_src.md)** for requirements, the `.env`
format, and the exact run order (offline tests → smoke test → small sample →
full runs). See **[`ProjectStatus.md`](ProjectStatus.md)** for current status,
design decisions, and deviations from the paper.

```
Rscript src/main.R tests        # offline, zero cost — start here
Rscript src/main.R              # show all commands
```

## Layout

```
paper/        the paper (full text)
src-origin/   the authors' original notebooks (read-only reference)
data/         the four datasets (+ cache/, results/)
src/          the R implementation (see src/README_src.md)
report/       figures, tables, slides for the deliverable
```
