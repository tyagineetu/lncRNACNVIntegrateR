#' Preprocessing of input files
#'
#' @param expr_df data frame of expression values
#'
#' @param cnv_df data frame of absolute CNV values
#'
#' @param clin_df data frame of clinical values
#'
#' @return preprocessing_and_preparation_result
#'
#' @import DESeq2
#'
#' @import dplyr
#'
#' @import SummarizedExperiment
#'
#' @export
#'
#' @examples
#' preprocessing_and_preparation_result <- preprocessing_and_preparation(expr_df, cnv_df, clin_df)
preprocessing_and_preparation <- function(expr_df, cnv_df, clin_df) {

# Check and create the directory inside your function
output_dir <- file.path(getwd(), "lncRNACNVIntegrateR_output")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # Read expression data from file
  expression_data <- as.data.frame(expr_df)
  head(expression_data[1:10,1:10])

  # Shorten row names
  shortened_row_names <- substr(rownames(expression_data), 1, 12)

  # Check for duplicated shortened row names
  duplicated_shortened <- as.data.frame(duplicated(shortened_row_names))

  # Keep only the first occurrence of shortened row names and their corresponding expression data
  expression_data <- expression_data[!duplicated_shortened, ]

  rownames(expression_data) <- substr(rownames(expression_data), 1, 12)
  #return(expression_data)
  # Read CNV data from file
  # y <- input_cnv("/DATA1/descriptivestatistics/extdata/cnv_data_raw.csv")
  cnv_data <- as.data.frame(cnv_df)
  head(cnv_data[1:10,1:10])
  rownames(cnv_data) <- substr(rownames(cnv_data), 1, 12)
  for (i in 1:nrow(cnv_data)) {
    current_row_name <- rownames(cnv_data)[i]
    if (current_row_name != "-") {
      rownames(cnv_data)[i] <- gsub("\\.", "-", current_row_name)
    }
  }

  # Read clinical data from file
  clinical_data <- clin_df
  head(clinical_data[1:10,1:10])
  colnames(clinical_data) <- clinical_data[1,]
  clinical_data <- clinical_data[-(1:2),]
  selected_clin <- as.data.frame(clinical_data[, c("bcr_patient_barcode", "vital_status", "days_to_last_followup")])
  rownames(selected_clin) <- selected_clin[,1]
  selected_clin <- selected_clin[,-1]

  # Find common samples between CNV and expression data
  common_samples <- intersect(rownames(cnv_data), rownames(expression_data))

  if (length(common_samples) == 0) {
    stop("No common samples found between CNV and expression data.")
  }

  # Extract common samples from expression data
  #  df_gene_expr_data.t <- expression_data[common_samples, ]

  # Extract common samples from CNV data
  #  CNV_data_transposed <- cnv_data[common_samples, ]

  ### Fetch common samples from Clinical data ###
  clin_selected <- selected_clin[common_samples, ]
  clin_selected <- na.omit(clin_selected)
  #clin_selected <- clin_selected[!(clin_selected$days_to_last_followup == "[Not Available]"), ]
  raw_names_clin_data_avail <- rownames(clin_selected)

  head(clin_selected)

  ### now select the expression and CNV data for final common samples i.e., 483 ###

  df_gene_expr_data.t <- expression_data[raw_names_clin_data_avail, ]

  # Extract common samples from CNV data
  CNV_data_transposed <- cnv_data[raw_names_clin_data_avail, ]

  # Create metadata for DESeq2
  df_gene_expr_data.t2 <- t(df_gene_expr_data.t)
  column2 <- as.data.frame(colnames(df_gene_expr_data.t2))
  condn2 <- as.data.frame(rep("Case", times = nrow(column2)))
  metaData2 <- cbind(column2, condn2)
  colnames(metaData2)[1:2] <- c("Sample", "condition")

  # Create a DESeqDataSet object
  dds <- DESeq2::DESeqDataSetFromMatrix(df_gene_expr_data.t2, metaData2, design = ~1)
  # Run DESeq2
  ddsDE <- DESeq2::DESeq(dds)
  # Apply Variance Stabilizing Transformation
  vst_normal <- DESeq2::varianceStabilizingTransformation(ddsDE, blind = TRUE)
  vst_normal_results <- SummarizedExperiment::assay(vst_normal)
  ## firstly download the gtf file from gencode ####
  # URL to the GTF file (GENCODE version 22)
  gtf_url <- "https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_22/gencode.v22.annotation.gtf.gz"

  # Destination file path where you want to save the downloaded file
  # Get the current working directory
  current_working_directory <- getwd()

  # Set the destination path to the current working directory
  destination_path <- file.path(current_working_directory, "gencode.v22.annotation.gtf.gz")

  # Download the GTF file with a longer timeout
  download.file(url = gtf_url, destfile = destination_path, method = "wget", timeout = timeout_duration)

  # Uncompress the downloaded file if it's in .gz format
  if (grepl(".gz$", destination_path)) {
    system(paste("gunzip", destination_path))
    destination_path <- sub(".gz$", "", destination_path)
  }

  # Check if the download was successful
  if (file.exists(destination_path)) {
    cat("Downloaded GTF file successfully.\n")

    # Read the downloaded GTF file into a data frame
    gtf <- read.table(destination_path, header = FALSE, sep = "\t")

    # Optionally, you can add column names to the data frame if your GTF file doesn't have a header row
    # colnames(gtf) <- c("seqname", "source", "feature", "start", "end", "score", "strand", "frame", "attribute")

    # Now you have a data frame named "gtf" that you can process further
  } else {
    cat("Download failed. Please check the URL or your internet connection.\n")
  }
 # head(gtf[1:5,1:5])
 split_names <- strsplit(as.character(gtf$V9), ';')
 merged_df <- do.call(rbind, split_names)
  # Combine the merged columns with the original data frame
 df_merged <- cbind(gtf, merged_df)
  # Filter and subset lncRNA transcripts
  matched_processed_transcript <- subset(df_merged, grepl("processed_transcript", df_merged$'2', ignore.case = TRUE))
  prime_overlapping_ncrna <- subset(df_merged, grepl("3prime_overlapping_ncrna", df_merged$'2', ignore.case = TRUE))
  sense_intronic <- subset(df_merged, grepl("sense_intronic", df_merged$'2', ignore.case = TRUE))
  sense_overlapping <- subset(df_merged, grepl("sense_overlapping", df_merged$'2', ignore.case = TRUE))
  antisense <- subset(df_merged, grepl("antisense", df_merged$'2', ignore.case = TRUE))
  lncRNA <- subset(df_merged, grepl("lincRNA", df_merged$'2', ignore.case = TRUE))

  # Combine all lncRNA subsets into one data frame
  All_lnc <- rbind(matched_processed_transcript, prime_overlapping_ncrna, sense_intronic, sense_overlapping, antisense, lncRNA)

  # Extract and clean lncRNA names
  All_lnc_names <- as.data.frame(All_lnc$'4')
  All_lnc_names <- gsub("gene_name", "", All_lnc_names$`All_lnc$"4"`)
  All_lnc_names2 <- as.data.frame(All_lnc_names)
  All_lnc_names2_uniq <- unique(All_lnc_names2)
  colnames(All_lnc_names2_uniq)[colnames(All_lnc_names2_uniq) == "All_lnc_names"] <- "Name"

  ### Now fetch for PCGs ###

  Protein_coding_genes <- subset(df_merged, grepl("protein_coding", df_merged$'2', ignore.case = TRUE))
  All_PCG_names <- as.data.frame(Protein_coding_genes$'4')
  All_PCG_names <- gsub("gene_name", "", All_PCG_names$`Protein_coding_genes$"4"`)
  All_PCG_names2 <- as.data.frame(All_PCG_names)
  All_PCG_names2_uniq <- unique(All_PCG_names2)
  colnames(All_PCG_names2_uniq)[colnames(All_PCG_names2_uniq) == "All_PCG_names"] <- "Name"

  # Extract gene names from All_lnc_names2_uniq
  PCG_names <- as.data.frame(trimws(All_PCG_names2_uniq$Name))  # Remove leading/trailing whitespaces


  # Now fetch the lncRNAs expression and CNV data from common samples
  # library(dplyr)

  vst_normal_results <- as.data.frame(t(vst_normal_results))
  gene_names <- as.data.frame(trimws(All_lnc_names2_uniq$Name))  # Remove leading/trailing whitespaces
  column_names <- as.data.frame(colnames(vst_normal_results))


  # Find the intersection of gene names and column names
  intersecting_genes <- intersect(gene_names$`trimws(All_lnc_names2_uniq$Name)`, column_names$`colnames(vst_normal_results)`)
  # Now you can use the select function
  result_df_Expr_lncRNAs <- vst_normal_results %>%
    select(all_of(intersecting_genes))

  # Find the intersection of gene names and column names
  intersecting_genes_PCGs <- intersect(PCG_names$`trimws(All_PCG_names2_uniq$Name)`, column_names$`colnames(vst_normal_results)`)
  # Now you can use the select function
  result_df_Expr_PCGs <- vst_normal_results %>%
    select(all_of(intersecting_genes_PCGs))
  # write.table(result_df_Expr_PCGs, "result_df_Expr_PCGs.txt", sep="\t", quote=FALSE)

  # Extract CNV data
  common_CNV_data <- as.data.frame(CNV_data_transposed)
  column_names_CNV <- as.data.frame(colnames(CNV_data_transposed))
  intersecting_genes_CNV <- intersect(gene_names$`trimws(All_lnc_names2_uniq$Name)`, column_names_CNV$`colnames(CNV_data_transposed)`)
  result_df_CNVs <- common_CNV_data %>% select(all_of(intersecting_genes_CNV))

  # Fetch lncRNAs expression only for those which have CNV call also
  col_new_lncRNA <- as.data.frame(colnames(result_df_Expr_lncRNAs))
  common_genes <- intersect(intersecting_genes_CNV, col_new_lncRNA$`colnames(result_df_Expr_lncRNAs)`)

  # Intersect genes that have expression also from the CNV data
  result_df_Expr_lncRNAs <- result_df_Expr_lncRNAs %>%
    select(all_of(common_genes))
  ### expression final matrix lncRNA ###
  head(result_df_Expr_lncRNAs[1:10,1:10])

  # Also fetch these from CNV as the number is not the same when fetched from expression data
  result_df_Expr_lncRNAs_with_CNV <- result_df_CNVs %>%
    select(all_of(common_genes))
  ### CNVs final matrix ###
  head(result_df_Expr_lncRNAs_with_CNV[1:10,1:10])

  # Return the data frames as a list
  return(list(result_df_Expr_lncRNAs = result_df_Expr_lncRNAs,
              result_df_Expr_lncRNAs_with_CNV = result_df_Expr_lncRNAs_with_CNV,
              clin_selected = clin_selected, PCG_matrix = result_df_Expr_PCGs))
}



