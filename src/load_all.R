# =============================================================================
# load_all.R — Load the whole R library into the session.
#
# Sources every module in src/R/ (plus the experiment helpers) in dependency
# order, so a single source() call makes all functions available. config.R is
# loaded first because it defines the paths, models, prompts and category maps
# that every other module relies on.
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
