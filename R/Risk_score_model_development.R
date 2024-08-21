#' Extracting key lncRNAs and development of risk score model for them
#'
#' @param result_surv list returned by extract_survival_related_significant_lncRNA
#'
#' @param result_visulaization list returned by visualization_of_lncRNA_and_CNVs_association
#'
#' @param merged_expression_clinical_data data frame of total lncRNAs expression values with clinical info
#'
#' @param significant_lncRNA_names_from_kruskal data frame of lncRNAs corresponding CNV details
#'
#' @return result_riskscore_model
#'
#' @import ggplot2
#'
#' @import dplyr
#'
#' @import purrr
#'
#' @import ggpubr
#'
#' @import survival
#'
#' @import survminer
#'
#' @import PredictABEL
#'
#' @export
#'
#' @examples
#' # Example 1: using the results from previous functions:
#' # Assuming result_surv and result_visulaization are obtained from the previous functions
#' result_riskscore_model <- Risk_score_model_development(result_surv = result_surv, result_visulaization = result_visulaization)
#'
#' # Example 2: providing the data frames directly:
#' # Assuming merged_df_fetched_lncRNAs_expression_df and significant_lncRNA_names_after_violin_plot_df are available
#' result_riskscore_model <- Risk_score_model_development(merged_df_fetched_lncRNAs_expression = merged_df_fetched_lncRNAs_expression_df, significant_lncRNA_names_after_violin_plot = significant_lncRNA_names_after_violin_plot_df)
Risk_score_model_development <- function(result_surv = NULL, result_visulaization = NULL, merged_df_fetched_lncRNAs_expression = NULL, significant_lncRNA_names_after_violin_plot = NULL) {

  if (!is.null(result_surv) && !is.null(result_visulaization)) {
    merged_df_fetched_lncRNAs_expression <- result_surv$merged_expr_clinical
    significant_lncRNA_names_after_violin_plot <- result_visulaization$GeneName
  } else if (!is.null(merged_df_fetched_lncRNAs_expression) && !is.null(significant_lncRNA_names_after_violin_plot)) {
  } else {
    stop("Either result_surv & result_visulaization or merged_df_fetched_lncRNAs_expression, significant_lncRNA_names_after_violin_plot must be provided.")  }
   all_col <- names(merged_df_fetched_lncRNAs_expression)
  get_cols <- significant_lncRNA_names_after_violin_plot
  get_cols <- unique(get_cols)
  add_cols <- c("vital_status", "days_to_last_followup")
  sel_cols <- c(get_cols, add_cols)

  data_2 <- merged_df_fetched_lncRNAs_expression %>%
    select(all_of(sel_cols[sel_cols %in% all_col]))

  data_2$days_to_last_followup <- as.numeric(data_2$days_to_last_followup)
  data_2[is.na(data_2)] <- 0

  cox_model <- coxph(Surv(days_to_last_followup, vital_status) ~ ., data = data_2)
  # Obtain the summary
  summary_cox_model <- summary(cox_model)

  # Extract relevant information
  result_df <- data.frame(
    covariate = rownames(summary_cox_model$coefficients),
    coef = summary_cox_model$coefficients[, "coef"],
    exp_coef = exp(summary_cox_model$coefficients[, "coef"]),
    se = summary_cox_model$coefficients[, "se(coef)"],
    z = summary_cox_model$coefficients[, "z"],
    p = summary_cox_model$coefficients[, "Pr(>|z|)"]
  )

  significant_list <- result_df %>% filter(p <= 0.05)

  selected_features <- significant_list$covariate
  all_columns <- names(data_2)

  additional_columns <- c("vital_status", "days_to_last_followup")

  # Combine selected features and additional columns
  all_selected_columns <- c(selected_features, additional_columns)

  # Filter the dataframe to include only the existing columns

  New_data <- merged_df_fetched_lncRNAs_expression %>%
    select(all_of(all_selected_columns[all_selected_columns %in% all_columns]))

  ### remove clinical data for biochemical recurrence ###
  #New_data_2 <- merge(New_data, selected_clin, by= "row.names")

  IDs <- as.data.frame(rownames(New_data))

  New_data2 <- cbind(IDs, New_data)

  colnames(New_data2)[1] <- "ID"
  #New_data2 <- New_data_2[,-(11)]
  #New_data2$biochemical_recurrence <- ifelse(New_data2$biochemical_recurrence == "NO", 0, 1)
  #rownames(New_data2) <- New_data2[,1]
  New_data3 <- New_data2[, -ncol(New_data2)]

  # Calculate the three-quarters length of the total columns in New_data3
  # three_quarters_length <- floor(3 * (ncol(New_data3) - 2) / 4)  # Exclude ID and vital_status columns

  # Define the range of lncRNA combination lengths starting from the three-quarters length
  #  lncRNA_combinations_lengths <- seq(three_quarters_length, ncol(New_data3) - 2)

  # Generate all possible combinations of lncRNAs for each length
  #  all_lncRNA_combinations <- lapply(lncRNA_combinations_lengths,
  #                                   function(length) {
  #                                    combinat::combn(names(New_data3)[-c(1, ncol(New_data3))], length)
  #                                 })

  # Example usage: print the combinations for length three_quarters_length
  # print(all_lncRNA_combinations[[1]])

  #### new code added #####

  # Specify the number of lncRNAs you want to combine (e.g., 4, 5, 6, 7)
  # library(combinat)

  # Initialize variables to store best combinations and AUROC values
  # best_combinations <- list()
  # best_auroc_values <- numeric()

  #  for (i in 1:length(all_lncRNA_combinations)) {
  #    current_lncRNA_combinations <- all_lncRNA_combinations[[i]]

  #   if (is.matrix(current_lncRNA_combinations)) {
  #   for(j in 1:ncol(current_lncRNA_combinations)) {
  #     selected_lncRNAs <- current_lncRNA_combinations[, j]

  #    subset_data1 <- New_data3[, c(selected_lncRNAs, "vital_status")]
  #   cOutcome <- ncol(subset_data1)
  #  cGenPred1 <- setdiff(1:ncol(subset_data1), cOutcome)

  # riskmodel_temp <- fitLogRegModel(data = subset_data1, cOutcome = cOutcome, cGenPreds = cGenPred1)

  #auroc_value <- plotROC(subset_data1, "vital_status", predRisk(riskmodel_temp))$auc

  #print(paste0("Combination ", j, ": ", paste(selected_lncRNAs, collapse = ", "), " - AUROC:", auroc_value))
  #}
  #} else {
  # Single combination case
  # selected_lncRNAs <- current_lncRNA_combinations
  #  subset_data1 <- New_data3[, c(selected_lncRNAs, "vital_status")]
  #  cOutcome <- ncol(subset_data1)
  #  cGenPred1 <- setdiff(1:ncol(subset_data1), cOutcome)
  #  riskmodel_temp <- fitLogRegModel(data = subset_data1, cOutcome = cOutcome, cGenPreds = cGenPred1)
  # auroc_value <- plotROC(subset_data1, "vital_status", predRisk(riskmodel_temp))$auc
  # Check if auroc_value is not NA or NULL and if it's higher than the best so far
  #  print(paste0("Combination 1: ", paste(selected_lncRNAs, collapse = ", "), " - AUROC:", auroc_value))
  #}
  #  }

  # Print the best combination and AUROC value
  # print(paste0("Best Combination: ", paste(unlist(best_combination), collapse = ", "), " - Best AUROC:", best_auroc_value))


  # library(PredictABEL)

  cOutcome <- as.numeric(ncol(New_data3))

  # Create cGenPred1 by excluding columns
  cGenPred1 <- as.numeric(setdiff(2:ncol(New_data3), cOutcome))

  riskmodel1 <- fitLogRegModel(data = New_data3, cOutcome = cOutcome, cGenPreds = cGenPred1)
  summary(riskmodel1)
  predRisk <- predRisk(riskmodel1)

  # Save ROC plot
  png("ROC_plot.png", width = 12, height = 8, units = "in", res = 300)
  plotROC(New_data3, cOutcome, predRisk)
  dev.off()

  # Display ROC plot in R window
  plotROC(New_data3, cOutcome, predRisk)

  # Capture console output to a variable
  roc_stats <- capture.output(plotROC(New_data3, cOutcome, predRisk))


  # Save the captured statistics to a file
  writeLines(roc_stats, "ROC_statistics.txt")

  riskScore <- riskScore(weights = riskmodel1, data = New_data3, cGenPreds = cGenPred1, Type = "weighted")
  RiskScore <- cbind(New_data3$ID, riskScore)
  colnames(RiskScore)[2] <- "risk_score"
  RiskScore <- as.data.frame(RiskScore)
  RiskScore$risk_score <- as.numeric(RiskScore$risk_score)
  median_score <- median(RiskScore$risk_score)
  high_risk <- as.data.frame(RiskScore[RiskScore$risk_score >= median_score, ])
  low_risk <- as.data.frame(RiskScore[RiskScore$risk_score < median_score, ])

  # Combine risk score information with clinical information
  test <- as.data.frame(rownames(high_risk))
  test2 <- as.data.frame(rep("H", times = nrow(test)))
  high_risk_1 <- cbind(high_risk, test2)
  rownames(high_risk_1) <- high_risk_1[, 1]
  colnames(high_risk_1)[3] <- "Risk"
  colnames(high_risk_1)[1] <- "ID"
  high_risk_plus_clinical <- merge(high_risk_1, New_data2, by = "row.names")

  # For low risk group
  test3 <- as.data.frame(rownames(low_risk))
  test4 <- as.data.frame(rep("L", times = nrow(test3)))
  low_risk_1 <- cbind(low_risk, test4)
  rownames(low_risk_1) <- low_risk_1[, 1]
  colnames(low_risk_1)[3] <- "Risk"
  colnames(low_risk_1)[1] <- "ID"
  low_risk_plus_clinical <- merge(low_risk_1, New_data2, by = "row.names")

  # At last rbind to the two H and L
  merged_high_low_risk <- rbind(high_risk_plus_clinical, low_risk_plus_clinical)
  merged_high_low_risk$days_to_last_followup <- as.numeric(merged_high_low_risk$days_to_last_followup)
  merged_high_low_risk[is.na(merged_high_low_risk)] <- 0

  fit6 <- survfit(Surv(days_to_last_followup, vital_status) ~ Risk, data = merged_high_low_risk)
  png("survival_plot.png", width = 12, height = 8, units = "in", res = 300)
  plot_survival <- ggsurvplot(
    fit6,
    pval = TRUE,
    conf.int = FALSE,
    font.main = c(20, "bold"),
    font.submain = c(20, "bold"),
    font.caption = c(20, "bold"),
    font.x = c(16, "bold"),
    font.y = c(16, "bold"),
    font.tickslab = c(12, "plain"),
    ggtheme = theme_bw(),
    risk.table = TRUE,            # Show the risk table
    risk.table.col = "strata",    # Use different colors for different strata (high and low-risk groups)
    risk.table.fontsize = 4,     # Font size for the risk table
    risk.table.title = "Risk Table",  # Title of the risk table
    risk.table.y.text = TRUE,      # Display the numbers at risk on the y-axis
    data = merged_high_low_risk
    )
  print(plot_survival)
  dev.off()

  # Display survival plot in R window
  print(plot_survival)
   return(final_expre_matrix_prognostic_markers = New_data)

}
