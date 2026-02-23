#' De-identify machine extraction data
#'
#' This function is used to de-identify a flat file using a crosswalk (with
#' specific structure, see \code{loadxwalks()}).
#' De-identification options include replacing a patient MRN by a tokenized MRN
#' (using the crosswalk), removing a column, 'blanking' a column
#' (the column remains in the dataset but all values are ""), and shifting a
#' date, datetime, or Unix epoch time variable (using the crosswalk).
#'
#'
#'
#' @param filetodeid character. Filename of a single flat file to de-identify.
#' @param fd_varname_mrn character. Name of MRN variable in file to de-identify. Default is "PAT_MRN".
#' @param variablestoremove character vector. Names of variables in extraction file to remove. Default is \code{character(0)}, no variables to remove.
#' @param variablestoblank character vector. Names of variables in extraction file to blank. The variable will remain in the output file but will be '' for all rows. Default is \code{character(0)}, no variables to blank.
#' @param datevariablestodateshift character vector. Names of variables that are dates and should be date-shifted. Default is \code{character(0)}, no variables to shift.
#' @param dateformat character. Format of date variables in the extraction file.  Default is "%Y-%m-%d" corresponding to 4-digit year, hyphen, 2-digit month, hyphen, 2-digit day.
#' @param datetimevariablestodateshift character vector. Names of variables that are datetimes and should be date-shifted. Default is \code{character(0)}, no variables to shift.
#' @param datetimeformat character. Format of datetime variables in the extraction file.  Default is "%Y-%m-%d %H:%M:%OS" corresponding to 4-digit year, hyphen, 2-digit month, hyphen, 2-digit day, space, 2-digit (24) hour, colon, 2-digit minute, colon 2-digit second.
#' @param epochvariablestodateshift character vector. Names of variables that represent
#' Unix epoch time (seconds since 1970-01-01 00:00:00 UTC) and should be shifted.
#' Values may be stored as integer seconds or floating-point seconds (allowing
#' fractional seconds). Default is \code{character(0)}, no variables to shift.
#' @param separator character. Field separator in filetodeid (input file). Default is \code{","}.
#' @param separator_out character. Field separator to use in outputfile. Default is \code{","}.
#' @param xwalk data.frame containing crosswalk information. Usually the output from [loadxwalks()].
#' @param compare_mrn_numeric logical. Should MRNs be compared as numeric variables? Usually this is a good idea because leading 0s may have been dropped during processing. Default is whatever was used to create xwalk, which is \code{TRUE} by default.
#' @param outputfile character. Name of file to write de-identified data. If \code{NULL} (the default) the data are not written, but only returned from the function. An additional option is the special value \code{"SOURCE_"}, which causes the output to be written to the same filename as the input but prepended with "SOURCE_".
#' @param usefread If \code{TRUE} (default), use \code{data.table::fread()} and \code{data.table::fwrite()}. If \code{FALSE}, use \code{utils::read.csv()} and \code{utils::write.csv()}. \code{TRUE} is usually preferable as \code{FALSE} results in double quotes around almost all values when producing the output file.
#' @param verbose integer. Higher values produce more output to console.  Default is 0, no output.
#'
#' @details
#' Date variables are shifted by adding \code{SHIFT_NUM} days.
#' Datetime variables are shifted by adding \code{86400 * SHIFT_NUM} seconds.
#' Epoch variables are shifted by adding \code{86400 * SHIFT_NUM} seconds directly
#' to the numeric epoch value.
#'
#' All epoch values are assumed to represent seconds since
#' 1970-01-01 00:00:00 UTC. No timezone conversion is performed.
#'
#' @return (invisibly) data.frame (even if \code{usefread == TRUE}) with variables tokenized, date-shifted, removed, and/or blanked, as requested.
#' @export
#'
#' @examples
#' dataloc <- system.file("extdata", package = "DeIDmachinedata")
#' fn1 <- sprintf("%s/xwalk1.csv", dataloc)
#' fn2 <- sprintf("%s/xwalk2.csv", dataloc)
#' xwalk <- loadxwalks(tokenfile = fn1, dateshiftfile = fn2)
#' fn3 <- sprintf("%s/pentacam_UCH.csv", dataloc)
#' deidfile <- fileDeID(
#'   filetodeid = fn3,
#'   fd_varname_mrn = "Pat-ID:",
#'   variablestoremove = c("Last Name:", "First Name:", "D.o.Birth:"),
#'   variablestoblank = "Exam Comment:",
#'   datevariablestodateshift = "Exam Date:",
#'   epochvariablestodateshift = "ExamTimeUnix",
#'   dateformat = "%m/%d/%Y",
#'   xwalk = xwalk,
#'   outputfile = NULL,
#'   verbose = 2)
#' deidfile
fileDeID <- function(
    filetodeid,
    fd_varname_mrn = "PAT_MRN",
    variablestoremove = character(0),
    variablestoblank = character(0),
    datevariablestodateshift = character(0),
    dateformat = "%Y-%m-%d",
    datetimevariablestodateshift = character(0),
    datetimeformat = "%Y-%m-%d %H:%M:%OS",

    # NEW: epoch variables (seconds since 1970-01-01 UTC)
    epochvariablestodateshift = character(0),

    separator = ",",
    separator_out = ",",

    xwalk,

    compare_mrn_numeric = attr(xwalk, "compare_mrn_numeric"),

    outputfile = NULL,
    usefread = TRUE,
    verbose = 0L) {

  if (missing(xwalk))
    stop("xwalk must be provided. See loadxwalks().")

  if (!("PAT_MRN" %in% names(xwalk)))
    stop("PAT_MRN must be a column in xwalk.")

  if (!("PAT_MRN_T" %in% names(xwalk)))
    stop("PAT_MRN_T must be a column in xwalk.")

  if (!("SHIFT_NUM" %in% names(xwalk)) &&
      ((length(datevariablestodateshift) > 0) ||
       (length(datetimevariablestodateshift) > 0) ||
       (length(epochvariablestodateshift) > 0)))
    stop("SHIFT_NUM must be a column in xwalk if any time variables are to be shifted.")

  if (missing(filetodeid))
    stop("Must provide file to deidentify.")

  if (length(filetodeid) > 1L)
    stop("Deidentify one file at a time.")

  if (verbose > 0L) cat(sprintf("Processing %s\n", filetodeid))

  varnames <- if (isTRUE(usefread)) {
    names(data.table::fread(
      file = filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE,
      data.table = FALSE,
      nrows = 0))
  } else {
    names(utils::read.table(
      filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE,
      nrows = 0))
  }

  if (verbose > 1L) {
    cat(sprintf("%s Variable Names\n", filetodeid))
    print(varnames)
  }

  vartype <- rep("character", length(varnames))
  names(vartype) <- varnames

  if (any(is.na(match(variablestoremove, varnames))))
    warning(sprintf("Not all variables in variablestoremove found in %s", filetodeid))
  if (any(is.na(match(variablestoblank, varnames))))
    warning(sprintf("Not all variables in variablestoblank found in %s", filetodeid))
  if (any(is.na(match(datevariablestodateshift, varnames))))
    warning(sprintf("Not all variables in datevariablestodateshift found in %s", filetodeid))
  if (any(is.na(match(datetimevariablestodateshift, varnames))))
    warning(sprintf("Not all variables in datetimevariablestodateshift found in %s", filetodeid))
  if (any(is.na(match(epochvariablestodateshift, varnames))))
    warning(sprintf("Not all variables in epochvariablestodateshift found in %s", filetodeid))
  if (is.na(match(fd_varname_mrn, varnames)))
    stop(sprintf("%s not a variable in %s", fd_varname_mrn, filetodeid))

  vartype[intersect(variablestoremove, varnames)] <- "NULL"

  dat <- if (isTRUE(usefread)) {
    data.table::fread(
      file = filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE,
      data.table = FALSE,
      colClasses = vartype)
  } else {
    utils::read.table(
      filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE,
      colClasses = vartype)
  }

  if (isTRUE(compare_mrn_numeric)) {
    dat[, fd_varname_mrn] <- as.numeric(dat[, fd_varname_mrn])
  }

  dat[, intersect(variablestoblank, names(dat))] <- NA_character_

  codingindex <- match(dat[, fd_varname_mrn], xwalk[, "PAT_MRN"])
  dat[, fd_varname_mrn] <- xwalk[codingindex, "PAT_MRN_T"]

  if (verbose > 0L)
    cat(sprintf(
      "%6d tokenized mrns missing of %6d\n",
      sum(is.na(dat[, fd_varname_mrn])), nrow(dat)))

  # ---------------------------
  # TIME SHIFTING SECTION
  # ---------------------------

  if ((length(datevariablestodateshift) > 0L) ||
      (length(datetimevariablestodateshift) > 0L) ||
      (length(epochvariablestodateshift) > 0L)) {

    dat[, "SHIFT_NUM_tEmP"] <- xwalk[codingindex, "SHIFT_NUM"]

    # Date variables
    for (variabletodateshift in datevariablestodateshift) {
      if (verbose > 0L) cat(sprintf("Shifting %s\n", variabletodateshift))
      dat[, variabletodateshift] <-
        format(
          as.Date(dat[, variabletodateshift], format = dateformat) +
            dat[, "SHIFT_NUM_tEmP"],
          format = "%Y-%m-%d")
    }

    # Datetime variables
    for (variabletodateshift in datetimevariablestodateshift) {
      if (verbose > 0L) cat(sprintf("Shifting %s\n", variabletodateshift))

      # fix the problem of leading zeros (if the date string is imported as an integer):
      pad_left_zero <- function(x, width) {
		  x <- trimws(format(x, scientific = FALSE))
		  paste0(strrep("0", pmax(0, width - nchar(x))), x)
	  }
      datestrings <- switch(datetimeformat,
		  "%y%m%d%H%M%S" = pad_left_zero(dat[[variabletodateshift]], 12),
		  "%y%m%d%H%M"   = pad_left_zero(dat[[variabletodateshift]], 10),
		  dat[[variabletodateshift]])

      dat[, variabletodateshift] <-
        format(
           as.POSIXct(datestrings, format = datetimeformat, tz = "GMT") +
            86400 * dat[, "SHIFT_NUM_tEmP"],
          format = "%Y-%m-%d %H:%M:%S",
          tz = "GMT",
          usetz = FALSE)
    }

    # Epoch variables (seconds since 1970-01-01 UTC, integer or float)
    for (variabletodateshift in epochvariablestodateshift) {
      if (verbose > 0L) cat(sprintf("Shifting %s (epoch seconds)\n", variabletodateshift))
      dat[, variabletodateshift] <-
        as.numeric(dat[, variabletodateshift]) +
        86400 * dat[, "SHIFT_NUM_tEmP"]
    }

    dat[, "SHIFT_NUM_tEmP"] <- NULL
  }

  # ---------------------------
  # WRITE OUTPUT
  # ---------------------------

  if (!is.null(outputfile)) {

    if (isTRUE(outputfile == "SOURCE_")) {
      sss <- strsplit(filetodeid, split = "/", fixed = TRUE)[[1]]
      sss[length(sss)] <- sprintf("SOURCE_%s", sss[length(sss)])
      outputfile <- paste(sss, collapse = "/")
    }

    if (verbose > 0L) cat(sprintf("Writing to %s\n", outputfile))

    if (isTRUE(usefread)) {
      data.table::fwrite(
        dat,
        file = outputfile,
        sep = separator_out,
        row.names = FALSE,
        na = "")
    } else {
      utils::write.table(
        dat,
        file = outputfile,
        sep = separator_out,
        qmethod = "double",
        row.names = FALSE,
        na = "")
    }
  }

  return(invisible(dat))
}
