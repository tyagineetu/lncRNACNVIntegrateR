#' Preparing input files
#'
#' @param file_path character string indicating a tab delimited expression file path
#'
#' @return x data frame of expression values
#'
#'  @import utils
#'
#' @export
#'
#' @examples
#' expr_df <- input_expr("/DATA1/lncRNACNVIntegrateR/extdata/gene_expression_COAD.txt.gz")
input_expr <- function(file_path) {
  if (grepl("\\.gz$", file_path)) {
    con <- gzfile(file_path, "rt")
    x <- read.table(con, header = TRUE, sep = "\t", stringsAsFactors = FALSE)
    close(con)
  } else {
    x <- read.table(file_path, header = TRUE, sep = "\t", stringsAsFactors = FALSE)
  }
  return(x)
}

