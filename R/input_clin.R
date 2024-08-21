#' Preparing input files
#'
#' @param file_path character string indicating a tab delimited clinical file path
#'
#' @return z data frame of selected clinical data
#'
#' @import utils
#' @import readr
#' @export
#'
#' @examples
#' clin_df <- input_clin("/DATA1/lncRNACNVIntegrateR/extdata/clinical_data_COAD.txt.gz")
input_clin <- function(file_path) {
  if (is.character(file_path)) {
    if (grepl("\\.gz$", file_path)) {
      con <- gzfile(file_path, "rt")
      z <- read.table(con, header = TRUE, sep = "\t", row.names = 1, stringsAsFactors = FALSE)
      close(con)
    } else {
      z <- read.table(file_path, header = TRUE, sep = "\t", row.names = 1, stringsAsFactors = FALSE)
    }
    z <- as.data.frame(z)
    return(z)
  } else {
    stop("Invalid input. Please provide a correct file path.")
  }
}
