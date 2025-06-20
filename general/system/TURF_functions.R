# ---- Define Functions ----
`%ni%` <- Negate(`%in%`)

# cbind for data.frames with different numbers of rows
cbind2 <- function (...){
  nm <- list(...)
  nm <- lapply(nm, as.matrix)
  n  <- max(sapply(nm, nrow))
  do.call(cbind, 
          lapply(nm, function(x) rbind(x, matrix(, n - nrow(x), ncol(x))))) %>% data.frame()
}

# Function to drop columns that may or may not exist
drop_cols <- function(df, ...){
  df %>% select(-one_of(map_chr(enquos(...), quo_name)))
}

# Removes prefix 
remove_prefix <- function(val,prefix) {
  as.numeric(str_sub(val, start=nchar(prefix)+1))
}

# Function to reorder items to match optimization order
reorder_items <- function(df) {
  new_df <- list()
  ref_row <- df[1,]
  new_df[[1]] <- ref_row
  for (i in 2:nrow(df)) {
    old_row <- df[i,]
    new_row <- old_row[order(match(old_row[!is.na(old_row)], ref_row[!is.na(ref_row)]))]
    names(new_row) <- names(df)[1:length(new_row)]
    new_df[[i]] <- new_row
    ref_row <- new_row
  }
  return(bind_rows(new_df))
}

#Function to generate options from file
turf.options <- function(df){
  top <- df %>% filter(Option=="Top") %>% pull(Value)
  sigtest <- df %>% filter(Option=="SigTest") %>% pull(Value)
  methodology <- df %>% filter(Option=="Methodology") %>% pull(Value)
  kpi <- sigtest <- df %>% filter(Option=="KPI") %>% pull(Value)
  none <- df %>% filter(Option=="None") %>% pull(Value)
  threshold <- df %>% filter(Option=="Threshold") %>% pull(Value)
  calculation <- df %>% filter(Option=="Calculation") %>% pull(Value)
  total_volume <- df %>% filter(Option=="TotalVolume") %>% pull(Value)
  exponent <- df %>% filter(Option=="Exponent") %>% pull(Value)
  use_bucks <- df %>% filter(Option=="Bucketing") %>% pull(Value)
  use_prohs <- df %>% filter(Option=="Prohibitions") %>% pull(Value)
  options <- list(
    top=as.numeric(top),
    sigtest=as.numeric(sigtest),
    methodology=methodology,
    kpi=kpi,
    none=as.logical(none), 
    threshold=as.numeric(threshold),
    calculation=calculation,
    total_volume=as.numeric(total_volume),
    exponent=as.numeric(exponent), 
    use_bucks=as.logical(use_bucks),
    use_prohs=as.logical(use_prohs)
  )
  return(options)
}
  

# Function to generate inputs from file
turf.inputs <- function(df){
  n <- nrow(df %>% filter(Item != "none")) 
  item_wei <- df %>% select(Weight) %>% t()
  dist <- df$Distribution
  size <- df$Size
  price <- df$Price
  cost <- df$Cost
  lst_comp <- df %>% filter(Owner == "Competitor") %>% pull(Item)
  df <- df %>% filter(Owner == "Client")
  lst_fixed <- df %>% filter(Fixed == "Yes") %>% pull(Item)
  df <- df %>% filter(Fixed == "No")
  n_bucks <- n_distinct(df$Bucket)
  n_bucks <- if (n_bucks == 1) 0 else n_bucks
  bucks <- list()
  for (i in seq_len(n_bucks)){
    buck <- df %>% filter(Bucket == i) %>% select(Item)
    bucks <- append(bucks, buck)
  }
  inputs <- list(
    n=n,
    dist=dist,
    item_wei=item_wei,
    size=size,
    price=price,
    cost=cost,
    lst_fixed=lst_fixed,
    lst_comp=lst_comp,
    n_bucks=n_bucks,
    bucks=bucks
  )
  return(inputs)
}

# Function to zero-center utilities
fix.utils <- function(utils, control){
  if (!is.null(control$anchoring)){
    if (control$anchoring == "unanchored") {
    utils <- utils - rowMeans(utils)
    }
  }
  return(utils)
}

# Function for generating prohibitions from file
get.prohibitions <- function(df,n_prohs) {
  prohs <- lapply(split(df, seq(nrow(df))), 
                  function(row) row[!is.na(row)])
  if (n_prohs == 1) prohs <- list( c(prohs) )
  return(prohs)
}

# Function for generating allowed combinations
get.combinations <- function(k,control){
  if (control$n_bucks == 0 | !control$use_bucks){
    elem <- setdiff(control$lst_cte, control$iter_fixed)
    nck <- data.frame(t(combn(elem,k)))
  } else if (control$n_bucks > 0 & control$use_bucks){
    partition <- blockparts(control$lims,k)
    nck <- data.frame()
    for (part in asplit(partition,2)){
      df <- mapply(function(k,buck) data.frame(t(combn(buck,k))),
                   part,control$bucks,SIMPLIFY=F) %>% reduce(.,full_join,by=character())
      colnames(df) <- sapply(1:ncol(df), function(i) paste0("X",i))
      nck <- rbind(nck,df)
    }
  }
  if (k > 1) {
    for (proh in control$prohs){
      nck <- nck[!apply(nck,1,function(comb) all(proh %in% comb)),]
    }
  }
  
  return(nck)
}

# Function for generating combinations' dummies
get.dummies <- function(nck,control){
  if (length(nck)==1) colnames(nck) <- "X"
  nck <- dummy_cols(nck,select_columns=colnames(nck),
                    remove_selected_columns=TRUE)
  head <- unique(gsub("X[0-9]+", "", colnames(nck)))
  nck <- sapply(head, 
                function(x)rowSums(nck[endsWith(colnames(nck), x)]))
  nck <- if (is.null(dim(nck))) nck %>% 
    as.matrix() %>% t() %>% data.frame() else nck %>% data.frame()
  colnames(nck) <- sapply(colnames(nck),
                          function(col) str_sub(col,start=3))
  for (x in control$iter_fixed) { 
    nck[[as.name(x)]] <- 1 
  }
  for (x in control$lst_comp) { 
    nck[[as.name(x)]] <- 1 
  }
  for (x in setdiff(control$lst_cte, as.numeric(colnames(nck)))) {
    nck[[as.name(x)]] <- 0
  }
  nck <- nck[, order(as.numeric(colnames(nck)))]
  return(nck)
}

redistribute <- function(pref,dist){
  base <- pref * dist
  remain <- pref - base
  redist <- (sum(remain) - remain) * base
  share <- ((redist / sum(redist)) * sum(remain)) %>% ifelse(is.na(.),0,.) + base
  return(share)
}

get.kpi <- function(sop, size, price, cost, 
                    total_vol, which="Preference Share"){
  sop <- sop %>% data.frame()
  if (which == "Preference Share"){
    return(sop)
  } else if (which == "Revenue"){
    rev <- (total_vol * sop / size) * price
    return(rev)
  } else if (which == "Value Share"){
    rev <- (total_vol * sop / size) * price
    val <- rev/sum(rev)
    return(val)
  } else if (which == "Profit"){
    profit <- (total_vol * sop / size) * (price - cost)
    return(profit)
  } else{
    tokens <- strsplit(which, "\\s|\\+|\\*")[[1]]
    tokens <- tokens[tokens != ""] %>% lapply(., type.convert, as.is=T)
    weis <- lapply(seq(1,length(tokens),2),function(i) tokens[[i]] )
    kpis <- lapply(seq(2,length(tokens),2),
                   function(i) get.kpi(sop,size,price,cost,total_vol,tokens[[i]]) )
    obj_func <- mapply("*", weis, kpis, SIMPLIFY=F) %>% Reduce("+", .)
    return(obj_func)
  }
}

# Iteration of TURF Analysis
turf.iter <- function(i,nck_bin,utils,control,ttest.data=FALSE){
  comb <- nck_bin[i,]
  items <- copy(comb)
  items[] <- sapply(1:ncol(comb), 
                    function(i) ifelse(comb[i]==1,
                                       paste0(control$prefix,colnames(comb)[i]),0))
  items <- items %>% select(-which(comb == 0)) %>% 
    select_if(colnames(.) %ni% control$lst_comp) %>% drop_cols(none)
  case_util <- mapply(`*`, utils, comb*control$item_wei) #%>% Matrix(data=.,sparse=TRUE)
  if (control$calculation == "SoP") {
    case_sop <- control$wei * (case_util / rowSums(case_util))
  } else if (control$calculation == "SoP Redistributed") {
    case_sop <- case_util / rowSums(case_util)
    case_sop <- control$wei * ( apply(case_sop,1,
                                      function(sop) redistribute(sop,control$dist)) %>% t() )
  } else if (control$calculation == "First Choice") {
    if (control$methodology != "CBC") {
      case_max  <- rowMax(mapply(`*`,utils[,-(n+1)],control$item_wei[-(n+1)]))
    } else if (control$methodology == "CBC") {
      case_max  <- rowMax(case_util)
    }
    case_sop <- control$ wei * ( apply(case_util,2,
                                       function(col) ifelse(col == case_max,1,0)) ) #%>% Matrix(data=.,sparse=TRUE)
  } else if (control$calculation == "Threshold") {
    case_sop <- control$wei * (case_util / rowSums(case_util))
    case_sop <- apply(case_sop,2,
                      function(col) ifelse(col >= control$threshold,1,0)) 
  }
  item_sop <- colSums(case_sop) / sum(control$wei)
  item_kpi <- get.kpi(item_sop,control$size,control$price,
                      control$cost,control$total_volume,control$kpi)
  colnames(item_kpi) <- i
  cte_kpi <- sum(item_kpi[control$lst_cte,]) %>% data.frame()
  colnames(cte_kpi) <- control$kpi
  items <- items %>% select_if(colnames(.) %ni% control$lst_fixed)
  colnames(items) <- 1:ncol(items)
  output <- cbind(cte_kpi,items)
  if (ttest.data) {
    ttest_sop <- rowSums(case_sop[,control$lst_cte]) %>% data.frame()
    colnames(ttest_sop) <- paste0("comb",i)
    output <- list(output,ttest_sop)
  } 
  return(output)
} 

# Function that runs TURF Analysis
run.turf <- function(nck_bin,utils,control,ttest.data=FALSE){
  n_comb <- nrow(nck_bin)
  results <- future_lapply(1:n_comb, 
                           function(i) turf.iter(i,nck_bin,utils,control,ttest.data))
  if (ttest.data) {
    cte_KPI   <- do.call(rbind,future_lapply(results,"[[",1))
    cte_KPI   <- cte_KPI[order(cte_KPI[,control$kpi],decreasing=TRUE),]
    ttest_SoP <- do.call(cbind2, future_lapply(results,"[[",2))
    return(list(cte_KPI,ttest_SoP))
  } else {
    cte_KPI <- do.call(rbind,results)
    cte_KPI <- cte_KPI[order(cte_KPI[,control$kpi],decreasing=TRUE),]
    return(cte_KPI)
  }
}

# Function for determining "optimal" k-partition
steps <- function(array,m,k,threshold=10000){
  mCk <- function(m,k) prod(setdiff(1:m, 1:(m-k))) / prod(1:k)
  if (mCk(m,k) <= threshold) {
    array <- append(array,k)
    return(array[order(array)])
  } else {
    ki <- sapply(1:(k-1), 
                 function(i) mCk(m,i)) %>% ifelse(.<=threshold,.,0) %>% which.max()
    ki <- if (k - ki > 1) ki else ki - 1
    array <- append(array,ki)
    steps(array,m-ki,k-ki)
  }
}

# Function that implements greedy approach for TURF Analysis 
stepwise.turf <- function(k,utils,control,start_from=NULL){
  m <- length(setdiff(control$lst_cte,control$lst_fixed))
  k_iter <- steps(c(),m,k) # rep(1,k)
  stepwise <- if (length(k_iter) > 1) TRUE else FALSE
  if(stepwise & control$n_bucks > 0 & control$use_bucks){
    showNotification("The stepwise+swapping method is not yet implemented for bucketed optimization, changing to full-search method instead...")
    stepwise <- FALSE
    k_iter <- c(k)
  }
  control$iter_fixed <- control$lst_fixed
  start_from <- start_from[[as.name(k_iter[1])]]
  if (stepwise & !is.null(start_from)) {
    best <- start_from[1,2:ncol(start_from)]
    control$iter_fixed <- append(control$iter_fixed,
                                 sapply(best, function(i) remove_prefix(i,control$prefix)))
    k_iter <- k_iter[2:length(k_iter)]
  }
  results <- NULL
  for (i in seq_along(k_iter)) {
    nck <- get.combinations(k_iter[i],control)
    nck_bin <- get.dummies(nck,control)
    nck_bin$none <- if (control$none) 1 else 0
    if (i < length(k_iter)) {
      results <- run.turf(nck_bin,utils,control)
      best <- results[1,2:ncol(results)]
      control$iter_fixed <- append(control$iter_fixed,
                                   sapply(best,function(i) remove_prefix(i,control$prefix)))
    } else {
      results <- run.turf(nck_bin,utils,control)
    }
  }
  if (stepwise) {
    control$iter_fixed <- control$lst_fixed
    results <- results %>% 
      rbind(.,run.swapping(results,utils,control))
    results <- results[!duplicated(results),]
    results <- results[order(results[,control$kpi],decreasing=TRUE),]
    colnames(results) <- c(control$kpi,sapply(1:k,function(i) paste0(i, "° Item")))
    results <- list("stepwise+swapping",results)
  } else {
    colnames(results) <- c(control$kpi,sapply(1:k,function(i) paste0(i, "° Item")))
    results <- list("full-search",results)
  }
  return(results)
}

# Iteration of swapping algorithm
swap <- function(comb,control){
  comb <- comb[,2:ncol(comb)]
  comb <- mapply(function(x) remove_prefix(x,control$prefix), comb)
  alt <- setdiff(control$lst_cte,comb)
  alt <- setdiff(alt,control$lst_fixed)
  output <- c()
  for (i in seq_along(comb)) {
    new <- copy(comb)
    for (j in alt) {
      new[i] <- j
      output <- rbind(output,new[order(new)])
    }
  }
  output <- output %>% data.frame()
  rownames(output) <- 1:nrow(output)
  return(output)
}

# Function that runs swapping
run.swapping <- function(results,utils,control){
  top100 <- min(nrow(results),100)
  swapped <- future_lapply(1:top100,
                           function(i) swap(results[i,],control))
  swapped <- do.call(rbind,swapped)
  swapped <- swapped[!duplicated(swapped),]
  swap_bin <- swapped %>% get.dummies(.,control)
  swap_bin$none <- if (control$none) 1 else 0
  output <- run.turf(swap_bin,utils,control)
  return(output)
}

# Function that performs a paired t-test over the top K combos
paired.ttest <- function(results,utils,control) {
  if (dim(results)[1] == 1) return(results)
  results <- results[1:min(nrow(results),control$top),]
  rn <- rownames(results)
  results <- results[,2:ncol(results)] %>%
    mapply(function(x) remove_prefix(x,control$prefix),.)
  results_bin <- results %>% 
    data.frame() %>% get.dummies(.,control)
  results_bin$none <- if (control$none) 1 else 0
  ttest_data <- run.turf(results_bin,utils,control,ttest.data=TRUE)
  output <- ttest_data[[1]]
  ttest_data <- ttest_data[[2]]
  p_val   <- c(1)
  sig_val <- c("==")
  i0 <- 1
  for (i in 2:nrow(output)) {
    test <- t.test(ttest_data[[as.name(paste0("comb",i0))]],
                   ttest_data[[as.name(paste0("comb",i))]], paired=TRUE)
    p_val[[i]] <- test$p.value
    if (test$p.value < control$alpha) {
      i0 <- i
      sig_val[[i]] <- "***"
    } else {
      sig_val[[i]] <- "=="
    }
  }
  output$pvalue <- p_val
  output$sigtest <- sig_val
  rownames(output) <- rn
  return(output)
}