library(renv)
renv::restore()

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)

#working_dir <<- args[1]
k <<- as.numeric(args[2])

# Set working directory
setwd(working_dir)

# Run TURF
message(sprintf("Running"))
script_path <- file.path(working_dir, "TURF_run.R")
source(script_path)
