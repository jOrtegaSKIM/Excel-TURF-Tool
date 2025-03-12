library(future)
library(openxlsx)
library(tidyverse)
library(future.apply)

library(Matrix)
library(data.table)
library(partitions)
library(fastDummies)

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

#control$lims <- sapply(seq_len(control$n_buks),
#                       function(i) get("input")[[paste0("lim_",i)]])

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

if (is.null(control$anchoring) & !control$None) {
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
#k <- if (input$range) input$krange[1]:input$krange[2] else input$k

if (length(k) == 1) {
  results <<- stepwise.turf(k,utils,control)
} else {
  results <<- lapply(k, function(i) NULL)
  names(results) <- k
  for (ki in k) {
    res <- stepwise.turf(ki,utils,control,
                         start_from=results)
    results[[as.name(ki)]] <<- res[[2]]
  }
  results_all <- do.call(bind_rows, (lapply(results, function(x) x[1,])))
  results_all[,-1] <- reorder_items(results_all[,-1])
}

write.csv(results[[2]],"TURF_results.csv", row.names=F)