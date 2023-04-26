#' De-identify machine extraction data
#'
#' @param filetodeid A single csv file to de-identify.
#' @param fd_varname_mrn Name of mrn variable in file to de-identify. Default is PAT_MRN.
#' @param variablestoremove Names of variables in extraction file to remove. Default is character(0), no variables to remove.
#' @param variablestoblank  Names of variables in extraction file to blank. The variable will remain in the output file but will be "" for all rows. Default is character(0), no variables to blank.
#' @param datevariablestodateshift Names of variables that are dates and should be date-shifted. Default is character(0), no variables to shift.
#' @param dateformat Format of date variables in the extraction file.  Default is "%Y-%m-%d" corresponding to 4-digit year, hyphen, 2-digit month, hyphen, 2-digit day.
#' @param datetimevariablestodateshift Names of variables that are datetimes and should be date-shifted. Default is character(0), no variables to shift.
#' @param datetimeformat Format of date variables in the extraction file.  Default is "%Y-%m-%d %H:%M:%OS" corresponding to 4-digit year, hyphen, 2-digit month, hyphen, 2-digit day, space, 2-digit (24) hour, colon, 2-digit minute, colon 2-digit second.
#' @param separator Field separator in filetodeid. Default is ",".
#' @param separator_out Field separator to use in outputfile. Default is ",".
#' @param xwalk data.frame containing cross walk information. Usually the output from loadxwalks().
#' @param compare_mrn_numeric Should MRNs be compared as numeric variables? Usually this is a good idea because leading 0s may have been dropped during processing. Default is whatever was used to create xwalk, which is TRUE by default.
#' @param outputfile Name of file to write de-identified data. If NULL (the default) the data are not written, only returned from the function.
#' @param usefread If TRUE (default), use data.table::fread and data.table::fwrite. If FALSE, use utils::read.csv and utils::write.csv. TRUE is preferable as the latter adds double quotes around almost all values when producing output file.
#' @param verbose Higher values produce more output to console.  Default is 0, no output.
#'
#' @return data.frame (invisibly and even if usefread == TRUE) with variables tokenized, dateshifted, removed, and blanked, as requested.
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

    verbose = 0) {

  if (missing(xwalk)) stop("xwalk must be provided. See loadxwalks().")
  if (!("PAT_MRN" %in% names(xwalk))) stop("PAT_MRN must be a column in xwalk.")
  if (!("PAT_MRN_T" %in% names(xwalk))) stop("PAT_MRN_T must be a column in xwalk.")
  if (!("SHIFT_NUM" %in% names(xwalk)) && ((length(datevariablestodateshift)>1) || length(datetimevariablestodateshift)>1)) stop("SHIFT_NUM must be a column in xwalk if any date or datetime variables are to be shifted.")


  # File(s) to Deidentify
  if (missing(filetodeid)) stop("Must provide file to deidentify.")
  if (length(filetodeid)>1) stop("Deidentify one file at a time.")


  if (verbose > 0) cat(sprintf("Processing %s\n", filetodeid))

  varnames <- if (isTRUE(usefread)) {
    names(data.table::fread(
      file = filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE, # default, actually
      data.table = FALSE,
      nrows = 0))
  } else if (isFALSE(usefread)) {
    names(utils::read.table(
      filetodeid,
      header = TRUE,
      na.strings = "",
      sep = separator,
      check.names = FALSE, # allow non-standard names
      nrows = 0)) # To get variable names
  } else stop("usefread must be TRUE or FALSE.")

  if (verbose > 1) {
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

  if (verbose > 0) {
    cat(sprintf("%d rows read from %s\n", nrow(dat), filetodeid))
    if (verbose > 1) {
      print(utils::head(dat))
    }
  }

  # convert character to numeric
  if (isTRUE(compare_mrn_numeric)) {
    dat[, fd_varname_mrn] <- as.numeric(dat[, fd_varname_mrn])
  }

  # blank those to be blanked
  # dat[intersect(variablestoblank, names(dat))] <- ""
  # this version is written more compactly. i.e., ,, vs ,"",
  dat[intersect(variablestoblank, names(dat))] <- NA_character_

  # use crosswalk
  # replace mrn with tokenized mrn
  # add date_shift variable.
  # preserve order of dat
  codingindex <- match(dat[, fd_varname_mrn], xwalk[, "PAT_MRN"])
  if (verbose > 1) {
    cat("summary of MRN matching index\n")
    print(summary(codingindex))
  }

  if (verbose > 1) {
    cat("Number of patients with each number of test (original MRN)\n")
    print(table(table(dat[, fd_varname_mrn], useNA = "ifany")))
  }

  # replace PAT_MRN by PAT_MRN_T
  dat[, fd_varname_mrn] <- xwalk[codingindex, "PAT_MRN_T"]
  if (verbose > 1) {
    cat("Number of patients with each number of test (tokenized MRN)\n")
    print(table(table(dat[, fd_varname_mrn], useNA = "ifany")))
  }

  if (verbose > 0) cat(sprintf("%6d tokenized mrns missing of %6d\n", sum(is.na(dat[, fd_varname_mrn])), nrow(dat)))

  # if there are any variables to date shift, then add SHIFT_NUM and add to dates
  if ((length(datevariablestodateshift) > 0) || (length(datetimevariablestodateshift) > 0)) {
    dat[, "SHIFT_NUM_tEmP"] <- xwalk[codingindex, "SHIFT_NUM"] # add SHIFT_NUM variable

    # for each date variable, ADD SHIFT_NUM days
    for (variabletodateshift in datevariablestodateshift) {
      if (verbose > 0) cat(sprintf("Shifting %s\n", variabletodateshift))
      if (verbose > 1) print(utils::head(dat[, variabletodateshift]))
      dat[, variabletodateshift] <-
        format(
          as.Date(
            dat[, variabletodateshift],
            format = dateformat) +
            dat[, "SHIFT_NUM_tEmP"],
          format = "%Y-%m-%d") # output in the SOURCE Date Format Standard
      if (verbose > 1) print(utils::head(dat[, variabletodateshift]))
    }
    # for each datetime variable, ADD 86400 SHIFT_NUM seconds
    for (variabletodateshift in datetimevariablestodateshift) {
      if (verbose > 0) cat(sprintf("Shifting %s\n", variabletodateshift))
      if (verbose > 1) print(utils::head(dat[, variabletodateshift]))
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
      if (verbose > 1) print(utils::head(dat[, variabletodateshift]))
    }

    # remove SHIFT_NUM from dataset
    dat[, "SHIFT_NUM_tEmP"] <- NULL
  }

  if (!is.null(outputfile)) {
    cat(sprintf("Writing to %s\n", outputfile))
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

# ddd <- fileDeID(
#   filetodeid = "J:/FORUM Data/CSV/2005/UM_OPH_VISUAL_FIELD.csv",
#   fd_varname_mrn = "MRN",
#   variablestoremove = c("X", "MRN0", "DOB", "Age", "Sex", "Institution"),
#   variablestoblank = "Name",
#   datevariablestodateshift = "TestDate",
#   dateformat = "%Y%m%d",
#   datetimevariablestodateshift = "TestDateTime",
#   xwalk = xwalk,
#   verbose = 2
# )
