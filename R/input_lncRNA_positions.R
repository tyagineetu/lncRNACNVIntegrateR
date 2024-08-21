#' Reading the lncRNA positions in the genome
#'
#' @return l data frame of lncRNA positions
#'
#' @import utils
#'
#' @import here
#'
#' @export
#'
#' @examples
#' lncRNA_positions <- input_lncRNA_positions()
input_lncRNA_positions <- function() {
  file_path <- system.file("extdata", "all_lncRNAs_positions.txt", package = "lncRNACNVIntegrateR")
  if (!file.exists(file_path)) {
    stop("The file does not exist: ", file_path)
  }
  lncRNA_positions <- read.table(file_path, header = TRUE, sep = "\t")
  return(lncRNA_positions)
}
