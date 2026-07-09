######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# load_all.R — load the whole R library into the session.
# Sources every module in dependency order (config.R first: it defines what the
# rest use). One source("src/load_all.R") makes all functions available.
######################################

source("src/R/config.R")     # paths, models, prompts, categories, .env keys
source("src/R/stats.R")      # SS / EBT / BF / interpretation
source("src/R/parse.R")      # response parsing
source("src/R/datasets.R")   # CrowS / BBQ / Winogender loaders
source("src/R/collect.R")    # API client + cache + run_dataset
source("src/R/analysis.R")   # aggregate + paper reference + compare
source("src/R/report.R")     # tables + figures
source("src/experiments/helpers.R")  # experiment orchestration helpers
