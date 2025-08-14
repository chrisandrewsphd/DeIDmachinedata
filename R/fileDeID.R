#' De-identify machine extraction data
#'
#' This function is used to de-identify a flat file using a crosswalk (with
#' specific structure, see \code{loadxwalks()}).
#' De-identification options include replacing a patient MRN by a tokenized MRN
#' (using the crosswalk), removing a column, 'blanking' a column
#' (the column remains in the dataset but all values are ""), and shifting a
#' date or datetime variable (using the crosswalk).
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
#' @param separator character. Field separator in filetodeid (input file). Default is \code{","}.
#' @param separator_out character. Field separator to use in outputfile. Default is \code{","}.
#' @param xwalk data.frame containing crosswalk information. Usually the output from [loadxwalks()].
#' @param compare_mrn_numeric logical. Should MRNs be compared as numeric variables? Usually this is a good idea because leading 0s may have been dropped during processing. Default is whatever was used to create xwalk, which is \code{TRUE} by default.
#' @param outputfile character. Name of file to write de-identified data. If \code{NULL} (the default) the data are not written, but only returned from the function. An additional option is the special value \code{"SOURCE_"}, which causes the output to be written to the same filename as the input but prepended with "SOURCE_".
#' @param usefread If \code{TRUE} (default), use \code{data.table::fread()} and \code{data.table::fwrite()}. If \code{FALSE}, use \code{utils::read.csv()} and \code{utils::write.csv()}. \code{TRUE} is usually preferable as \code{FALSE} results in double quotes around almost all values when producing the output file.
#' @param verbose integer. Higher values produce more output to console.  Default is 0, no output.
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
#'   dateformat = "%m/%d/%Y",
#'   xwalk = xwalk,
#'   outputfile = NULL,
#'   verbose = 2)
#' deidfile # Note last test was on a person not in the crosswalk
fileDeID <- function(
    filetodeid,
    fd_varname_mrn = "PAT_MRN",
    variablestoremove = character(0),
    variablestoblank = character(0),
    datevariablestodateshift = character(0),
    dateformat = "%Y-%m-%d",
    datetimevariablestodateshift = character(0),
    datetimeformat = "%Y-%m-%d %H:%M:%OS",
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
       length(datetimevariablestodateshift) > 0))
    stop("SHIFT_NUM must be a column in xwalk if any date or datetime variables are to be shifted.")


  # File to Deidentify
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
      check.names = FALSE, # default, actually
      data.table = FALSE,
      nrows = 0)) # To get variable names
  } else if (isFALSE(usefread)) {
    names(utils::read.table(
      filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE, # allow non-standard names
      nrows = 0)) # To get variable names
  } else stop("usefread must be TRUE or FALSE.")

  if (verbose > 1L) {
    cat(sprintf("%s Variable Names\n", filetodeid))
    print(varnames)
  }

  vartype <- rep("character", length(varnames)) # read all data as character by default
  names(vartype) <- varnames

  if (any(is.na(match(variablestoremove, varnames))))
    warning(sprintf("Not all variables in variablestoremove found in %s", filetodeid))
  if (any(is.na(match(variablestoblank, varnames))))
    warning(sprintf("Not all variables in variablestoblank found in %s", filetodeid))
  if (any(is.na(match(datevariablestodateshift, varnames))))
    warning(sprintf("Not all variables in datevariablestodateshift found in %s", filetodeid))
  if (any(is.na(match(datetimevariablestodateshift, varnames))))
    warning(sprintf("Not all variables in datetimevariablestodateshift found in %s", filetodeid))
  if (is.na(match(fd_varname_mrn, varnames)))
    stop(sprintf("%s not a variable in %s", fd_varname_mrn, filetodeid))

  # this doesn't do anything any more.
  vartype[fd_varname_mrn] <- if (isTRUE(compare_mrn_numeric)) {
    # "numeric" # errors if column is quoted in input file
    "character" # change to numeric after reading
  } else if (isFALSE(compare_mrn_numeric)) {
    "character"
  } else stop("compare_mrn_numeric must be TRUE or FALSE")

  # don't read those variables to be removed
  vartype[intersect(variablestoremove, varnames)] <- "NULL"

  dat <- if (isTRUE(usefread)) {
    data.table::fread(
      file = filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE, # allow non-standard names
      data.table = FALSE,
      colClasses = vartype)
  } else {
    utils::read.table(
      filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE, # allow non-standard names
      colClasses = vartype)
  }

  if (verbose > 0L) {
    cat(sprintf("%d rows read from %s\n", nrow(dat), filetodeid))
    if (verbose > 1L) {
      print(utils::head(dat))
    }
  }

  # convert character to numeric
  if (isTRUE(compare_mrn_numeric)) {
    dat[, fd_varname_mrn] <- as.numeric(dat[, fd_varname_mrn])
  }

  # blank those to be blanked
  # dat[intersect(variablestoblank, names(dat))] <- ""
  # this version is written more compactly by fwrite. i.e., ,, vs ,"",
  dat[, intersect(variablestoblank, names(dat))] <- NA_character_

  # use crosswalk
  # replace mrn with tokenized mrn
  # add date_shift variable.
  # preserve order of dat
  codingindex <- match(dat[, fd_varname_mrn], xwalk[, "PAT_MRN"])
  if (verbose > 1L) {
    cat("Summary of MRN matching index\n")
    print(summary(codingindex))
  }

  if (verbose > 1L) {
    cat("Number of patients with each number of test (original MRN)\n")
    print(table(table(dat[, fd_varname_mrn], useNA = "ifany")))
  }

  # replace PAT_MRN by PAT_MRN_T
  dat[, fd_varname_mrn] <- xwalk[codingindex, "PAT_MRN_T"]
  if (verbose > 1L) {
    cat("Number of patients with each number of test (tokenized MRN)\n")
    print(table(table(dat[, fd_varname_mrn], useNA = "ifany")))
  }

  if (verbose > 0L)
    cat(sprintf(
      "%6d tokenized mrns missing of %6d\n",
      sum(is.na(dat[, fd_varname_mrn])), nrow(dat)))

  # if there are any variables to date shift, then merge SHIFT_NUM and add to dates
  if ((length(datevariablestodateshift) > 0L) ||
      (length(datetimevariablestodateshift) > 0L)) {
    dat[, "SHIFT_NUM_tEmP"] <- xwalk[codingindex, "SHIFT_NUM"] # add SHIFT_NUM variable

    # for each date variable, ADD SHIFT_NUM days
    for (variabletodateshift in datevariablestodateshift) {
      if (verbose > 0L) cat(sprintf("Shifting %s\n", variabletodateshift))
      if (verbose > 1L) print(utils::head(dat[, variabletodateshift]))
      dat[, variabletodateshift] <-
        format(
          as.Date(
            dat[, variabletodateshift],
            format = dateformat) +
            dat[, "SHIFT_NUM_tEmP"],
          format = "%Y-%m-%d") # output in the SOURCE Date Format Standard
      if (verbose > 1L) print(utils::head(dat[, variabletodateshift]))
    }
    # for each datetime variable, ADD 86400 SHIFT_NUM seconds
    for (variabletodateshift in datetimevariablestodateshift) {
      if (verbose > 0L) cat(sprintf("Shifting %s\n", variabletodateshift))
      if (verbose > 1L) print(utils::head(dat[, variabletodateshift]))
      dat[, variabletodateshift] <-
        format(
          as.POSIXct(
            dat[, variabletodateshift],
            format = datetimeformat,
            tz = "GMT") + # do computation in GMT so Daylight Saving Time not used
            86400 * dat[, "SHIFT_NUM_tEmP"], # 24 * 60 * 60 = 86400
          format = "%Y-%m-%d %H:%M:%S", # output in the SOURCE DateTime Format Standard
          tz = "GMT", # do computation in GMT so Daylight Saving Time not used
          usetz = FALSE) # TZ not printed
      if (verbose > 1L) print(utils::head(dat[, variabletodateshift]))
    }

    # remove SHIFT_NUM from dataset
    dat[, "SHIFT_NUM_tEmP"] <- NULL
  }

  if (!is.null(outputfile)) {
    if (isTRUE(outputfile == "SOURCE_")) {
      # special case: add SOURCE_ to input filename to create output filename
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
        row.names = FALSE, # default, actually
        na = "") # default, actually
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
