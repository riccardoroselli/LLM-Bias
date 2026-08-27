# `outputs/` — generated results

Human-readable figures and tables produced by the experiments
(`Rscript src/main.R all`). The machine-readable CSV sources are in
`data/results/`; the slide deck built from these lives in `presentation/`.

The metrics shown (**SS** stereotype score, **EBT** exact binomial p-value, **BF₁₀**
Bayes factor) are explained in the **[project README](../README.md#the-idea)**;
the formulas themselves are in **[`src/R/stats.R`](../src/R/stats.R)**.

## `figures/`
- `fig2_crosslanguage.png` — Bayes factor per category, English vs French
  CrowS-Pairs (Experiment B / paper Fig 2).
- `fig3_temperature.png` — robustness of the test to sample size and temperature,
  BBQ Sexual-orientation (Experiment D / paper Fig 3).

## `tables/`
Paper-style Markdown tables (categories as columns; SS / EBT / BF as rows):
- `table3_crows_en_{chatgpt,deepseek}.md` — English CrowS-Pairs (Table 3).
- `crows_fr_{chatgpt,deepseek}.md` — French CrowS-Pairs.
- `table4_bbq_{chatgpt,deepseek}.md` — BBQ (Table 4).
- `table5_temperature.md` — temperature × sample-size grid (Table 5).

