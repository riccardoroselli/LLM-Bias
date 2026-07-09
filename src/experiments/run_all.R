######################################
# LLM-Bias reproduction — Statistics for Data Science, University of Pisa
#
# run_all.R — run experiments A -> E in order (the full reproduction).
# Sources each run_*.R in turn. Every experiment is cached and resumable, so the
# whole sequence is safe to interrupt and re-run. Dispatched by main.R as `all`.
######################################

# Run from the project root.
exp_dir = file.path("src", "experiments")

scripts = c(
  "run_A_crows_en.R",
  "run_B_crows_fr.R",
  "run_C_bbq.R",
  "run_D_temperature.R",
  "run_E_gender.R"
)

for (s in scripts) {
  message("\n############################################################")
  message("# ", s)
  message("############################################################")
  source(file.path(exp_dir, s))
}

message("\nAll experiments complete. Results in data/results/, ",
        "tables in outputs/tables/, figures in outputs/figures/.")
