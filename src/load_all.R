# =============================================================================
# load_all.R — Source every library module in dependency order.
#
# Usage (from any entry script; working directory anywhere inside the project):
#
#     .root <- getwd()
#     while (!file.exists(file.path(.root, "CLAUDE.md"))) {
#       .p <- dirname(.root); if (.p == .root) stop("Run inside the project"); .root <- .p
#     }
#     source(file.path(.root, "src", "load_all.R"))
#
# Library modules live in src/R/ (7 files). Experiment glue lives in
# src/experiments/helpers.R. Modules use `package::function` for all external
# packages, so *sourcing* them never requires a package to be installed — a
# package is only needed when a function that uses it is actually called. This
# keeps the offline tests dependency-light.
# =============================================================================

# Locate the project root from the current working directory, then src/.
.load_all_root <- local({
  dir <- normalizePath(getwd(), mustWork = FALSE)
  repeat {
    if (any(file.exists(file.path(dir, c("CLAUDE.md", ".git"))))) break
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      stop("load_all.R: could not find the project root from '", getwd(),
           "'. Set the working directory to somewhere inside the project.")
    }
    dir <- parent
  }
  dir
})
.SRC_DIR <- file.path(.load_all_root, "src")

# Library modules, in dependency order. config.R must be first (defines PATHS,
# MODELS, prompt builders, category maps, and loads .env keys).
.modules <- c(
  file.path("R", "config.R"),    # paths, models, prompts, categories, .env keys
  file.path("R", "stats.R"),     # SS / EBT / BF / interpretation
  file.path("R", "parse.R"),     # response parsing
  file.path("R", "datasets.R"),  # CrowS / BBQ / Winogender loaders
  file.path("R", "collect.R"),   # API client + cache + run_dataset
  file.path("R", "analysis.R"),  # aggregate + paper reference + compare
  file.path("R", "report.R"),    # tables + figures
  file.path("experiments", "helpers.R")  # experiment orchestration helpers
)

for (.m in .modules) {
  .path <- file.path(.SRC_DIR, .m)
  if (file.exists(.path)) source(.path)
}
rm(.m, .path)
