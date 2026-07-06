# `src/` — R implementation

The code that reproduces the paper's experiments. A single entry point
(`main.R`) drives everything; the reusable logic is a 7-module library in `R/`.

## Run it

Run from anywhere inside the project (scripts locate the root automatically):

```
Rscript src/main.R              # list all commands
Rscript src/main.R tests        # offline correctness suite — no API, no cost
Rscript src/main.R A            # one experiment: A, B, C, D, or E
Rscript src/main.R all          # every experiment in order (cached + resumable)
RUN_LIMIT=10 Rscript src/main.R A   # small-sample dry run (first 10 items)
```

## Requirements

- R (base packages only — no tidyverse).
- CRAN packages: `jsonlite`, `digest`, `httr2` (always); `ggplot2` (figures);
  `testthat` (tests).
  `install.packages(c("jsonlite","digest","httr2","ggplot2","testthat"))`
- API keys in the project-root `.env` (gitignored): `OPENAI=...` and
  `DEEPSEEK=...`. Read only by `config.R`; never printed or committed.

Modules reference external packages as `package::function`, so *sourcing* the
library needs nothing installed — a package is required only when a function that
uses it actually runs (which is why the offline tests are dependency-light).

## Layout

```
main.R          single entry point (command dispatch + how to run)
load_all.R      sources the library in dependency order
R/              the library (7 modules)
  config.R      paths, models, prompts, categories, .env key loading
  stats.R       stereotype score / exact binomial test / Bayes factor
  parse.R       parse 0/1 and ans0/1/2 responses (-> NA if unparseable)
  datasets.R    CrowS-Pairs, BBQ (+ 3-way -> binary resolver), Winogender loaders
  collect.R     API client + append-only response cache + collection engine
  analysis.R    responses -> metrics, the paper's published values, comparison
  report.R      CSV / Markdown tables + figures (ggplot2)
experiments/    run_A..E.R (one per experiment), run_all.R, helpers.R
tests/          run_tests.R + testthat/ — checks the code reproduces the
                paper's Tables 3/4, the loaders, the parser, and the BBQ resolver
```

Outputs are written to `data/results/` (CSVs), `outputs/tables/`, and
`outputs/figures/`.
