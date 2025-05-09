# helper to check whether package version is installed
in_env <- function(pkg, version) {
  if (!pkg %in% rownames(installed.packages())) return(FALSE)
  as.character(packageVersion(pkg)) == version
}

# install remotes if needed
if (!requireNamespace("remotes", quietly=TRUE)) {
  install.packages("remotes")
}

req_pkgs <- list(
  "future" = "1.34.0",
  "openxlsx" = "4.2.8",
  "tidyverse" = "2.0.0",
  "ggplot2" = "3.5.1",
  "tibble" = "3.2.1",
  "tidyr" = "1.3.1",
  "readr" = "2.1.5",
  "purrr" = "1.0.2", 
  "dplyr" = "1.1.4",
  "stringr" = "1.5.1",
  "forcats" = "1.0.0",
  "lubridate" = "1.9.4",
  "future.apply" = "1.11.3",
  "Matrix" = "1.7.0",
  "data.table" = "1.17.0",
  "partitions" = "1.10.7",
  "fastDummies" = "1.7.5"
)

for (pkg in names(req_pkgs)) {
  v_req <- req_pkgs[[pkg]]
  # install only if missing or wrong version is installed
  if (!in_env(pkg, v_req)) {
    message(paste0("Installing ", pkg, " ", v_req, "..."))
    remotes::install_version(
      package = pkg, 
      version = v_req, 
      repos   = "https://cloud.r-project.org",
      quiet = TRUE
    )
  } else {
    message(paste0(pkg, " ", v_req, " already installed."))
  }
  
}
