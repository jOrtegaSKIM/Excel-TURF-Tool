library(future, verbose=F, quietly=T)
library(openxlsx, verbose=F, quietly=T)
library(tidyverse, verbose=F, quietly=T)
library(future.apply, verbose=F, quietly=T)

library(Matrix, verbose=F, quietly=T)
library(data.table, verbose=F, quietly=T)
library(partitions, verbose=F, quietly=T)
library(fastDummies, verbose=F, quietly=T)

source("TURF_functions.R")

# ---- Load files ----
utils <- read.csv("utilities.csv")
inputfile <- read.csv("inputs.csv")
optionfile <- read.csv("options.csv")

# ---- Control list from optionfile and inputfile
control <- append(turf.options(optionfile), turf.inputs(inputfile))

# ---- Advanced settings ----
util_exp <- control$exponent
control$anchoring <- if (control$methodology == "MaxDiff") {
  "unanchored" 
} else if (control$methodology == "Anchored MaxDiff") {
  "anchored"
} else {
  NULL
}

# TODO: Handle buck lims
#control$use_bucks <- T
#control$buck_lims <- rep(1,9)

prohibfile <- if (control$use_prohs) read.csv("prohibitions.csv")
control$n_prohs <- if (control$use_prohs) nrow(prohibfile) else 0
control$prohs <- if (control$use_prohs) get.prohibitions(prohibfile,control$n_prohs) else list()

control$len_fixed <- length(control$lst_fixed)
control$len_comp  <- length(control$lst_comp)

control$lst <- 1:control$n
control$lst_cte <- setdiff(control$lst,control$lst_comp)

control$item_wei <- if (length(control$item_wei) == control$n) {
  cbind(control$item_wei,1) 
} else {
  control$item_wei
}
colnames(control$item_wei) <- c(control$lst,"none")

# ---- Clean utilities ----
control$wei  <- utils[,2]
utils <- (util_exp*utils[,-c(1,2)]) %>% fix.utils(control) %>% exp()
control$prefix <- unique(sub("^(\\D+).*", "\\1", colnames(utils)))[1]

# TODO: Redefine utils$none when control$anchoring == "unanchored"
if (is.null(control$anchoring) & !control$none) {
  utils$none <- 0 
} else if (!is.null(control$anchoring)) {
  if (control$anchoring == "anchored" & "none" %ni% colnames(utils)){
    utils$none <- 1
  } else if (control$anchoring == "unanchored") {
    utils$none <- control$n-1
  }
}

colnames(utils) <- append(control$lst, "none")

# ---- Run TURF ----
k <- 1:k

# Set parallel backend
plan(multisession)

if (length(k) == 1) {
  results <- stepwise.turf(k,utils,control)
  results <- results[[2]][results[[2]][,1] != 0,] 
  write.csv(results,"TURF_results.csv", row.names=F)
} else {
  results <- lapply(k, function(i) NULL)
  names(results) <- k
  for (ki in k) {
    if (ki == 1) {
      message(paste0("Setting up tool and running TURF for k=", ki, "..."))
    } else {
      message(paste0("Running TURF for k=", ki, "..."))
    }
    res <- stepwise.turf(ki,utils,control,
                         start_from=results)
    message(paste0("Finished running TURF for k=", ki))
    message(paste0("Saving results for k=", ki, " to 'TURF", ki, "_results.csv'"))
    results[[as.name(ki)]] <- res[[2]]
    write.csv(res[[2]], paste0("TURF",ki,"_results.csv"), row.names=F)
  }
  results_all <- do.call(bind_rows, (lapply(results, function(x) x[1,])))
  results_all[,-1] <- reorder_items(results_all[,-1])
  write.csv(results_all,"TURF_summary.csv", row.names=F)
}