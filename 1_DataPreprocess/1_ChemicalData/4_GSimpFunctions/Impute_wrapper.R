setwd("~/Library/CloudStorage/OneDrive-UniversityofNorthCarolinaatChapelHill/Rager_Lab/Projects_Lead/5_BEEWristband_Postpartum_ChemSS/4_Analyses/1_CurrentAnalyses/1_DataPreprocess/1_ChemicalData/4_GSimpFunctions")

# Imputation Wrapper ------------------------------------------------------
require(missForest)
require(impute)
require(magrittr)
require(imputeLCMD)
require(tidyverse)
source('MVI_global.R', local = TRUE)
source('GSimp.R', local = TRUE)

RF_wrapper <- function(data, ...) {
  result <- missForest(data, ...)[[1]]
  return (result)
}

kNN_wrapper <- function(data, ...) {
  result <- data %>% data.matrix %>% impute.knn(., ...) %>% extract2(1)
  return(result)
}

SVD_wrapper <- function(data, K = 5) {
  data_sc_res <- scale_recover(data, method = 'scale')
  data_sc <- data_sc_res[[1]]
  data_sc_param <- data_sc_res[[2]]
  result <- data_sc %>% impute.wrapper.SVD(., K = K) %>% 
    scale_recover(., method = 'recover', param_df = data_sc_param) %>% extract2(1)
  return(result)
}

Mean_wrapper <- function(data) {
  result <- data
  result[] <- lapply(result, function(x) {
    x[is.na(x)] <- mean(x, na.rm = T)
    x
  })
  return(result)
}

Median_wrapper <- function(data) {
  result <- data
  result[] <- lapply(result, function(x) {
    x[is.na(x)] <- median(x, na.rm = T)
    x
  })
  return(result)
}

HM_wrapper <- function(data) {
  result <- data
  result[] <- lapply(result, function(x) {
    x[is.na(x)] <- min(x, na.rm = T)/2
    x
  })
  return(result)
}

Zero_wrapper <- function(data) {
  result <- data
  result[is.na(result)] <- 0
  return(result)
}

QRILC_wrapper <- function(data, ...) {
  result <- data %>% log %>% impute.QRILC(., ...) %>% extract2(1) %>% exp
  return(result)
}

# pre_processing_GS_wrapper -----------------------------------------------
pre_processing_GS_wrapper <- function(data) {
  data_raw <- data
  ## log transformation ##
  data_raw_log <- data_raw %>% log()
  ## Initialization ##
  data_raw_log_qrilc <- impute.QRILC(data_raw_log) %>% extract2(1)
  ## Centralization and scaling ##
  data_raw_log_qrilc_sc <- scale_recover(data_raw_log_qrilc, method = 'scale')
  ## Data after centralization and scaling ##
  data_raw_log_qrilc_sc_df <- data_raw_log_qrilc_sc[[1]]
  ## Parameters for centralization and scaling ##
  ## For scaling recovery ##
  data_raw_log_qrilc_sc_df_param <- data_raw_log_qrilc_sc[[2]]
  ## NA position ##
  NA_pos <- which(is.na(data_raw), arr.ind = T)
  ## bala bala bala ##
  data_raw_log_sc <- data_raw_log_qrilc_sc_df
  data_raw_log_sc[NA_pos] <- NA
  ## Extract mdl vector
  data_raw_log_sc_mdlvec <- data_raw_log_sc %>%
    rownames_to_column("S_ID") %>%
    filter(S_ID == "mdl") %>%
    column_to_rownames("S_ID")
  
  data_raw_log_sc_mdlvec <- as.numeric(data_raw_log_sc_mdlvec[1, ])
  
  ## Remove mdl vector from data frame to be passed to imputation
  data_raw_log_sc <- data_raw_log_sc %>%
    rownames_to_column("S_ID") %>%
    filter(S_ID != "mdl") %>%
    column_to_rownames("S_ID")
  
  data_raw_log_qrilc_sc_df <- data_raw_log_qrilc_sc_df %>%
    rownames_to_column("S_ID") %>%
    filter(S_ID != "mdl") %>%
    column_to_rownames("S_ID")
  
  ## GSimp imputation with initialized data and missing data ##
  result <- data_raw_log_sc %>% GS_impute(., iters_each=50, iters_all=10, 
                                          initial = data_raw_log_qrilc_sc_df,
                                          lo=-Inf, hi= data_raw_log_sc_mdlvec, n_cores=1,
                                          imp_model='glmnet_pred')
  
  data_imp_log_sc <- result$data_imp
  
  ## Data recovery ##
  data_imp <- data_imp_log_sc %>% 
    scale_recover(., method = 'recover', 
                  param_df = data_raw_log_qrilc_sc_df_param) %>% 
    extract2(1) %>% exp()
  
  return(data_imp)
}
