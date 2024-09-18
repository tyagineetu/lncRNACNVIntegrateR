#' Preprocessing of input files
#'
#' @param expr_df data frame of expression values
#' @param cnv_df data frame of absolute CNV values
#' @param clin_df data frame of clinical values
#' @return List containing preprocessed expression and CNV matrices, along with clinical data
#' @import DESeq2
#' @import dplyr
#' @import SummarizedExperiment
#' @export
#' @examples
#' preprocessing_and_preparation_result <- preprocessing_and_preparation(expr_df, cnv_df, clin_df)

preprocessing_and_preparation <- function(expr_df, cnv_df, clin_df) {
  
  ## Preprocess Expression Data
  preprocess_expression_data <- function(expression_data) {
    shortened_row_names <- substr(rownames(expression_data), 1, 12)
    duplicated_shortened <- duplicated(shortened_row_names)
    expression_data <- expression_data[!duplicated_shortened, ]
    rownames(expression_data) <- substr(rownames(expression_data), 1, 12)
    return(expression_data)
  }
  
  ## Preprocess CNV Data
  preprocess_cnv_data <- function(cnv_data) {
    rownames(cnv_data) <- substr(rownames(cnv_data), 1, 12)
    for (i in 1:nrow(cnv_data)) {
      if (rownames(cnv_data)[i] != "-") {
        rownames(cnv_data)[i] <- gsub("\\.", "-", rownames(cnv_data)[i])
      }
    }
    return(cnv_data)
  }
  
  ## Preprocess Clinical Data
  preprocess_clinical_data <- function(clinical_data) {
    colnames(clinical_data) <- clinical_data[1, ]
    clinical_data <- clinical_data[-(1:2), ]
    selected_clin <- clinical_data[, c("bcr_patient_barcode", "vital_status", "days_to_last_followup")]
    rownames(selected_clin) <- selected_clin[, 1]
    selected_clin <- selected_clin[,-1]
    selected_clin <- na.omit(selected_clin)
    return(selected_clin)
  }
  
  ## Fetch Common Samples
  fetch_common_samples <- function(expr_data, cnv_data, clin_data) {
    common_samples <- intersect(intersect(rownames(expr_data), rownames(cnv_data)), rownames(clin_data))
    if (length(common_samples) == 0) stop("No common samples found between expression, CNV, and clinical data.")
    return(common_samples)
  }
  
  ## Fetch GTF Annotations
  fetch_gtf_annotations <- function(gtf_url, timeout_duration = 300) {
    destination_path <- file.path(getwd(), "gencode.v22.annotation.gtf.gz")
    download.file(gtf_url, destfile = destination_path, method = "wget", timeout = timeout_duration)
    if (grepl(".gz$", destination_path)) {
      system(paste("gunzip", destination_path))
      destination_path <- sub(".gz$", "", destination_path)
    }
    if (!file.exists(destination_path)) stop("GTF file download failed.")
    gtf <- read.table(destination_path, header = FALSE, sep = "\t")
    return(gtf)
  }
  
  ## Process GTF Annotations
  process_gtf_annotations <- function(gtf) {
    split_names <- strsplit(as.character(gtf$V9), ';')
    merged_df <- do.call(rbind, split_names)
    df_merged <- cbind(gtf, merged_df)
    
    # Filter for lncRNA and PCG subsets
    lncRNA_filter <- c("processed_transcript", "3prime_overlapping_ncrna", "sense_intronic", 
                       "sense_overlapping", "antisense", "lincRNA")
    lncRNA_df <- subset(df_merged, grepl(paste(lncRNA_filter, collapse = "|"), df_merged$'2', ignore.case = TRUE))
    lncRNA_names <- gsub("gene_name", "", lncRNA_df$'4')
    
    PCG_df <- subset(df_merged, grepl("protein_coding", df_merged$'2', ignore.case = TRUE))
    PCG_names <- gsub("gene_name", "", PCG_df$'4')
    
    return(list(lncRNA_names = unique(trimws(lncRNA_names)), PCG_names = unique(trimws(PCG_names))))
  }
  
  ## Normalize Expression Data using DESeq2
  normalize_expression_data <- function(expr_data, common_samples) {
    df_gene_expr_data <- t(expr_data[common_samples, ])
    meta_data <- data.frame(Sample = colnames(df_gene_expr_data), condition = rep("Case", ncol(df_gene_expr_data)))
    dds <- DESeq2::DESeqDataSetFromMatrix(countData = df_gene_expr_data, colData = meta_data, design = ~1)
    vst_result <- DESeq2::varianceStabilizingTransformation(DESeq2::DESeq(dds), blind = TRUE)
    return(SummarizedExperiment::assay(vst_result))
  }
  
  ## Match and Fetch LncRNA & PCG Data
  fetch_matched_data <- function(vst_data, cnv_data, lncRNA_names, PCG_names) {
    vst_data <- as.data.frame(vst_data)
    cnv_data <- as.data.frame(cnv_data)
    lncRNA_expr_data <- vst_data %>%
      select(all_of(intersect(lncRNA_names, colnames(vst_data))))
    
    PCG_expr_data <- vst_data %>%
      select(all_of(intersect(PCG_names, colnames(vst_data))))
    
    lncRNA_cnv_data <- cnv_data %>%
      select(all_of(intersect(lncRNA_names, colnames(cnv_data))))
    
    common_genes <- intersect(colnames(lncRNA_expr_data), colnames(lncRNA_cnv_data))
    lncRNA_expr_data_final <- lncRNA_expr_data %>%
      select(all_of(common_genes))
    
    lncRNA_cnv_data_final <- lncRNA_cnv_data %>%
      select(all_of(common_genes))
    
    return(list(lncRNA_expr_data = lncRNA_expr_data_final, lncRNA_cnv_data = lncRNA_cnv_data_final, PCG_expr_data = PCG_expr_data))
  }
  
  ## Main Processing Steps
  expression_data <- preprocess_expression_data(as.data.frame(expr_df))
  cnv_data <- preprocess_cnv_data(as.data.frame(cnv_df))
  clinical_data <- preprocess_clinical_data(as.data.frame(clin_df))
  
  common_samples <- fetch_common_samples(expression_data, cnv_data, clinical_data)
  
  normalized_expression <- normalize_expression_data(expression_data, common_samples)
  
  gtf_data <- fetch_gtf_annotations("https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_22/gencode.v22.annotation.gtf.gz")
  gtf_annotations <- process_gtf_annotations(gtf_data)
  
  matched_data <- fetch_matched_data(normalized_expression, cnv_data[common_samples, ], gtf_annotations$lncRNA_names, gtf_annotations$PCG_names)
  
  ## Return results as a list
  return(list(result_df_Expr_lncRNAs = matched_data$lncRNA_expr_data,
              result_df_Expr_lncRNAs_with_CNV = matched_data$lncRNA_cnv_data,
              clin_selected = clinical_data[common_samples, ],
              PCG_matrix = matched_data$PCG_expr_data))
}
