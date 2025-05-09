# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)

working_dir <<- args[1]
k <<- as.numeric(args[2])

# Set working directory
setwd(working_dir)

# Set up environment
message("Setting up environment. This may take a while...")
env_path <- file.path(working_dir, "TURF_env.R")
source(env_path)

# Run TURF
script_path <- file.path(working_dir, "TURF_run.R")
source(script_path)