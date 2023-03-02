loadxwalks <- function(
    tokenfile = NULL,
    t_varname_mrn = "PAT_MRN", # character(0),
    t_varname_mrn_token = "PAT_MRN_T", # character(0),
    
    dateshiftfile = NULL,
    ds_varname_mrn = "PAT_MRN",
    ds_varname_dateshift = "SHIFT_NUM",
    
    compare_mrn_numeric = TRUE, # if mrns are all digits, this can avoid problems with leading 0s.
    
    verbose = 0) {
  
  # Read and possibly merge crosswalks
  if (is.null(tokenfile) && is.null(dateshiftfile)) stop("Must provide tokenfile and/or dateshiftfile")
  
  if (!is.null(dateshiftfile)) {
    xwalk2names <- names(read.csv(dateshiftfile, header = TRUE, nrow = 0))
    
    if (verbose > 1) {
      cat("Date Shift Crosswalk Variable Names\n")
      print(xwalk2names)
    }
    
    # set up to read just two columns using a named vector for colClasses
    vartype <- rep("NULL", length(xwalk2names))
    names(vartype) <- xwalk2names
    
    if (is.na(match(ds_varname_mrn, xwalk2names)))
      stop(sprintf("%s not a variable in %s", ds_varname_mrn, dateshiftfile))
    if (is.na(match(ds_varname_dateshift, xwalk2names)))
      stop(sprintf("%s not a variable in %s", ds_varname_dateshift, dateshiftfile))
    
    # Would prefer the first, but there is a risk the file has quotes around
    # The date shift values.  So read as a character and then convert
    # vartype[ds_varname_dateshift] <- "integer"
    vartype[ds_varname_dateshift] <- "character"
    
    vartype[ds_varname_mrn] <- if (isTRUE(compare_mrn_numeric)) {
      # "numeric" # Same worry as above
      "character"
    } else if (isFALSE(compare_mrn_numeric)) {
      "character"
    } else stop("compare_mrn_numeric must be TRUE or FALSE.")
    
    xwalk2 <- read.csv(dateshiftfile, colClasses = vartype)
    
    if (verbose > 0) {
      cat(sprintf("%d rows read from %s\n", nrow(xwalk2), dateshiftfile))
      if (verbose > 1) {
        print(head(xwalk2))
      }
    }
    
    # convert character to numeric
    xwalk2[, ds_varname_dateshift] <- as.integer(xwalk2[, ds_varname_dateshift])
    if (isTRUE(compare_mrn_numeric)) {
      xwalk2[, ds_varname_mrn] <- as.numeric(xwalk2[, ds_varname_mrn])
    }
    
    # check uniqueness of crosswalk
    if (anyDuplicated(xwalk2)) {
      n0 <- nrow(xwalk2)
      xwalk2 <- unique(xwalk2)
      n2 <- nrow(xwalk2)
      if (verbose > 0) cat(sprintf("%s has duplicate mrn-date shift pairs. removing %d duplicates.\n", dateshiftfile, n0 - n2))
    }
    
    # check for more than 1 date shift for a single mrn
    if (anyDuplicated(xwalk2[[ds_varname_mrn]])) stop("Crosswalk not 1-1. One MRN has multiple date shifts.")
    
    if (verbose > 0) cat(sprintf("%d unique rows in %s\n", nrow(xwalk2), dateshiftfile))
    
    # Standardize variable names
    names(xwalk2)[match(c(ds_varname_mrn, ds_varname_dateshift), names(xwalk2))] <-
      c("PAT_MRN", "SHIFT_NUM")
  }
  
  if (!is.null(tokenfile)) {
    xwalk1names <- names(read.csv(tokenfile, header = TRUE, nrows = 0)) # To get variable names
    
    if (verbose > 1) {
      cat("Token Crosswalk Variable Names\n")
      print(xwalk1names)
    }
    
    vartype <- rep("NULL", length(xwalk1names))
    names(vartype) <- xwalk1names
    
    if (is.na(match(t_varname_mrn, xwalk1names)))
      stop(sprintf("%s not a variable in %s", t_varname_mrn, tokenfile))
    if (is.na(match(t_varname_mrn_token, xwalk1names)))
      stop(sprintf("%s not a variable in %s", t_varname_mrn_token, tokenfile))
    
    vartype[t_varname_mrn_token] <- "character"
    vartype[t_varname_mrn] <- if (isTRUE(compare_mrn_numeric)) {
      # "numeric" # See above
      "character"
    } else if (isFALSE(compare_mrn_numeric)) {
      "character"
    } else stop("compare_mrn_numeric must be TRUE or FALSE.")
    
    xwalk1 <- read.csv(tokenfile, colClasses = vartype)
    
    if (verbose > 0) {
      cat(sprintf("%d rows read from %s\n", nrow(xwalk1), tokenfile))
      if (verbose > 1) {
        print(head(xwalk1))
      }
    }
    
    # convert character to numeric
    if (isTRUE(compare_mrn_numeric)) {
      xwalk1[, t_varname_mrn] <- as.numeric(xwalk1[, t_varname_mrn])
    }
    
    # check uniqueness of crosswalk
    if (anyDuplicated(xwalk1)) {
      n0 <- nrow(xwalk1)
      xwalk1 <- unique(xwalk1)
      n1 <- nrow(xwalk1)
      if (verbose > 0) cat(sprintf("%s has duplicate mrn-mrn_token pairs. Removed %d duplicates.\n", tokenfile, n0 - n1))
    }
    
    # check for more than 1 token mrn for a single mrn
    if (anyDuplicated(xwalk1[, t_varname_mrn])) stop("Crosswalk not 1-1. One MRN has multiple tokenized MRNs.")
    # check for more than 1 mrn for a single token mrn
    if (anyDuplicated(xwalk1[, t_varname_mrn_token])) stop("Crosswalk not 1-1. One Tokenized MRN has multiple MRNs.")
    
    if (verbose > 0) cat(sprintf("%d unique rows in %s\n", nrow(xwalk1), tokenfile))
    
    # Standardize variable names
    names(xwalk1)[match(c(t_varname_mrn, t_varname_mrn_token), names(xwalk1))] <-
      c("PAT_MRN", "PAT_MRN_T")
    
    # check validity of tokens?
    # xwalk1 <- xwalk1[nchar(xwalk1$PAT_MRN) == 9 & nchar(xwalk1$PAT_MRN_T) == 44, ]
  }
  
  # combine both crosswalks
  xwalk <- if (exists("xwalk1", inherits = FALSE)) {
    if (exists("xwalk2", inherits = FALSE)) {
      merge(xwalk1, xwalk2, by = "PAT_MRN", all = FALSE) # only keep if both token and shift are available
    } else {
      xwalk1[order(xwalk1[, "PAT_MRN"]), ]
    }
  } else {
    if (exists("xwalk2", inherits = FALSE)) {
      xwalk2[order(xwalk2[, "PAT_MRN"]), ]
    } else {
      stop("No crosswalks read.")
    }
  }
  
  attr(xwalk, "compare_mrn_numeric") <- compare_mrn_numeric
  
  # data.frame with 2 or 3 columns:
  # PAT_MRN (always present, may be numeric or character),
  # PAT_MRN_T (character), and/or
  # SHIFT_NUM (integer)
  return(xwalk) 
}


# xwalk <- loadxwalks(
#   tokenfile = "J:/EPIC-Ophthalmology/DataMart/2022-11/all/full_pat_token_crosswalk.csv",
#   t_varname_mrn = "PAT_MRN", 
#   t_varname_mrn_token = "PAT_MRN_T",
#   dateshiftfile = "J:/EPIC-Ophthalmology/DataMart/2022-11/all/um_oph_pat_shift_num.csv", 
#   ds_varname_mrn = "PAT_MRN",
#   ds_varname_dateshift = "SHIFT_NUM", 
#   compare_mrn_numeric = TRUE,
#   verbose = 2)
# 
# 
# xwalk1 <- loadxwalks(
#   tokenfile = "J:/EPIC-Ophthalmology/DataMart/2022-11/all/full_pat_token_crosswalk.csv",
#   t_varname_mrn = "PAT_MRN", 
#   t_varname_mrn_token = "PAT_MRN_T",
#   compare_mrn_numeric = TRUE,
#   verbose = 2)
# 
# xwalk2 <- loadxwalks(
#   dateshiftfile = "J:/EPIC-Ophthalmology/DataMart/2022-11/all/um_oph_pat_shift_num.csv", 
#   ds_varname_mrn = "PAT_MRN",
#   ds_varname_dateshift = "SHIFT_NUM", 
#   compare_mrn_numeric = TRUE,
#   verbose = 2)

# xwalkF <- loadxwalks(
#   tokenfile = "J:/EPIC-Ophthalmology/DataMart/2022-11/all/full_pat_token_crosswalk.csv",
#   t_varname_mrn = "PAT_MRN",
#   t_varname_mrn_token = "PAT_MRN_T",
#   dateshiftfile = "J:/EPIC-Ophthalmology/DataMart/2022-11/all/um_oph_pat_shift_num.csv",
#   ds_varname_mrn = "PAT_MRN",
#   ds_varname_dateshift = "SHIFT_NUM",
#   compare_mrn_numeric = FALSE,
#   verbose = 2)

