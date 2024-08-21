#' Preparing input files
#'
#' @param file_path character string indicating a tab delimited CNV file path
#'
#' @return y data frame of absolute CNV values
#'
#' @import utils
#'
#' @export
#'
#' @examples
#' cnv_df <- input_cnv("/DATA1/lncRNACNVIntegrateR/extdata/CNV_data_COAD.txt.gz")

input_cnv <- function(file_path) {
  if (is.character(file_path)) {
    if (grepl("\\.gz$", file_path)) {
      con <- gzfile(file_path, "rt")
      y <- read.table(con, header = TRUE, sep = "\t", row.names = 1, stringsAsFactors = FALSE)
      close(con)
    } else {
      y <- read.table(file_path, header = TRUE, sep = "\t", row.names = 1, stringsAsFactors = FALSE)
    }
    y <- as.data.frame(y)
    return(y)
  } else {
    stop("Invalid input. Please provide a tab delimited file path.")
  }
}

