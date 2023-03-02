fileDeID <- function(
    filetodeid,
    fd_varname_mrn = "PAT_MRN",
    variablestoremove = character(0),
    variablestoblank = character(0),
    datevariablestodateshift = character(0),
    dateformat = "%Y-%m-%d",
    datetimevariablestodateshift = character(0),
    datetimeformat = "%Y-%m-%d %H:%M:%OS",
    
    xwalk,
    
    compare_mrn_numeric = attr(xwalk, "compare_mrn_numeric"),
    
    outputfile = NULL,
    
    verbose = 0) {
  
  if (missing(xwalk)) stop("xwalk must be provided. See loadxwalks().")
  if (!("PAT_MRN" %in% names(xwalk))) stop("PAT_MRN must be a column in xwalk.")
  if (!("PAT_MRN_T" %in% names(xwalk))) stop("PAT_MRN_T must be a column in xwalk.")
  if (!("SHIFT_NUM" %in% names(xwalk)) && ((length(datevariablestodateshift)>1) || length(datetimevariablestodateshift)>1)) stop("SHIFT_NUM must be a column in xwalk if any date or datetime variables are to be shifted.")
  

  # File(s) to Deidentify
  if (missing(filetodeid)) stop("Must provide file to deidentify.")
  if (length(filetodeid)>1) stop("Deidentify one file at a time.")
  
  
  if (verbose > 0) cat(sprintf("Processing %s\n", filetodeid))
  
  varnames <- names(read.csv(filetodeid, header = TRUE, nrows = 0)) # To get variable names
  
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
  
  dat <- read.csv(filetodeid, colClasses = vartype)
  
  if (verbose > 0) {
    cat(sprintf("%d rows read from %s\n", nrow(dat), filetodeid))
    if (verbose > 1) {
      print(head(dat))
    }
  }
  
  # convert character to numeric
  if (isTRUE(compare_mrn_numeric)) {
    dat[, fd_varname_mrn] <- as.numeric(dat[, fd_varname_mrn])
  }
  
  # blank those to be blanked
  dat[intersect(variablestoblank, names(dat))] <- "" 
  
  # use crosswalk
  # replace mrn with tokenized mrn
  # add date_shift variable.
  # preserve order of dat
  codingindex <- match(dat[, fd_varname_mrn], xwalk[, "PAT_MRN"])
  if (verbose > 1) print(summary(codingindex))
  
  if (verbose > 1) print(table(table(dat[, fd_varname_mrn], useNA = "ifany")))
  dat[, fd_varname_mrn] <- xwalk[codingindex, "PAT_MRN_T"]
  if (verbose > 1) print(table(table(dat[, fd_varname_mrn], useNA = "ifany")))
  
  if (verbose > 0) cat(sprintf("%6d tokenized mrns missing of %6d\n", sum(is.na(dat[, fd_varname_mrn])), nrow(dat)))

  # if there are any variables to date shift, then add SHIFT_NUM and add to dates
  if ((length(datevariablestodateshift) > 0) || (length(datetimevariablestodateshift) > 0)) {
    dat[, "SHIFT_NUM_tEmP"] <- xwalk[codingindex, "SHIFT_NUM"]
    
    # for each date variable, ADD SHIFT_NUM days
    for (variabletodateshift in datevariablestodateshift) {
      if (verbose > 0) cat(sprintf("Shifting %s\n", variabletodateshift))
      dat[, variabletodateshift] <-
        format(
          as.Date(
            dat[, variabletodateshift],
            format = dateformat) +
            dat[, "SHIFT_NUM_tEmP"],
          format = "%Y-%m-%d") # output in the SOURCE Date Format Standard
    }
    # for each datetime variable, ADD 86400 SHIFT_NUM seconds
    for (variabletodateshift in datetimevariablestodateshift) {
      if (verbose > 0) cat(sprintf("Shifting %s\n", variabletodateshift))
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
    }
  
    # remove SHIFT_NUM
    dat[, "SHIFT_NUM_tEmP"] <- NULL
  }
  
  if (!is.null(outputfile)) {
    cat(sprintf("Writing to %s\n", outputfile))
    write.csv(
      dat,
      file = outputfile,
      row.names = FALSE,
      na = "")
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
