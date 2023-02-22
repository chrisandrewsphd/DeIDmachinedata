fileDeID <- function(
    filetodeid,
    variablestoremove = character(0),
    variablestoblank = character(0),
    variablestotokenize = list(),
    variablestodateshift = character(0),
    tokenfile,
    
    dateshiftfile,
    varname_dateshift = "SHIFT_NUM",
    verbose = 0) {

  # De-ID FORUM CSV
  # A, FileName, Blank/Delete/Cut? Remove Directory portion? What is PHI? Replace by a VF_ID?
  # B, Name, Blank/Delete/Cut
  # C, MRN0, Blank/Delete/Cut (used to create D)
  # D, MRN, Replace with PAT_MRN (crosswalk or Datavant?). Add PAT_ID?
  # E, DOB, Blank/Delete/Cut (user should get from patient file)
  # F, Age, Blank/Delete/Cut (user should get DOB from patient file and compute age)
  # G, Sex, Blank/Delete/Cut (user should get from patient file)
  # H, Institution, Blank/Delete/Cut, Replace by Site_ID?
  # J, Date, Blank/Delete/Cut. (used to create L)
  # K, Time, Blank/Delete/Cut. (used to create L)
  # L, DateTime, Date-shift (crosswalk or Datavant?)
  # M-BO, no change
  
  
  # MRN to DATAVANT TOKEN and/or USID crosswalk
  xwalk1names <- names(read.csv(tokenfile, nrows = 0))
  vartype <- rep("NULL", length(xwalk1names))
  names(vartype) <- xwalk1names
  if (is.na(match(varname_mrn, xwalk1names))) stop(sprintf("%s not a variable in %s", varname_mrn, tokenfile))
  if (is.na(match(varname_mrn_token, xwalk1names))) stop(sprintf("%s not a variable in %s", varname_mrn_token, tokenfile))
  vartype[c(varname_mrn, varname_mrn_token)] <- "character"
  xwalk1 <- read.csv(tokenfile, colClasses = vartype)
  nx1 <- nrow(xwalk1)
  if (verbose > 0) cat(sprintf("%d rows in %s\n", nx1, tokenfile))
  
  # check uniqueness of crosswalk
  xwalk1 <- unique(xwalk1)
  if (nrow(xwalk1) < nx1) {
    warning(sprintf("%s has duplicate mrn-tokenized mrn pairs. removing duplicates.", tokenfile))
    nx1 <- nrow(xwalk1)
    if (verbose > 0) cat(sprintf("%d rows in %s\n", nx1, tokenfile))
  }
  # check 1-1 status
  if (anyDuplicated(xwalk1[[varname_mrn]])) stop("Crosswalk not 1-1. Duplicate mrns")
  if (anyDuplicated(xwalk1[[varname_mrn_token]])) stop("Crosswalk not 1-1. Duplicate tokenized mrns")

  # check validity of tokens?
  # xwalk1 <- xwalk1[nchar(xwalk1$PAT_MRN) == 9 & nchar(xwalk1$PAT_MRN_T) == 44, ]

  
  #########################
  ## RESUME HERE #
  ###########################
  # restore leading zeros?
  xwalk2 <- read.csv(
    "J:/EPIC-Ophthalmology/DataMart/2022-11/all/um_oph_pat_shift_num.csv",
    colClasses = c(PAT_ID = "NULL", PAT_MRN = "character", SHIFT_NUM = "integer", UNIQUE_SOURCE_ID = "NULL"),
    nrows = Inf)
  # dim(xwalk2) # 488205
  # head(xwalk2)
  # summary(xwalk2$SHIFT_NUM) # 1..9
  # anyDuplicated(xwalk2$PAT_MRN) # 0
  # table(nchar(xwalk2$PAT_MRN)) # 4 through 9 (no 0 though)
  xwalk2$PAT_MRN <- sprintf("%0.9d", as.numeric(xwalk2$PAT_MRN)) # restore leading 0s
  # table(nchar(xwalk2$PAT_MRN))
  
  
  # One yearly directory of XML files
  # root directory:
  xmlroot <- "J:/FORUM Data"
  # subdir <- "2005"
  # subdir <- "2022 November to December"
  
  for (subdir in c(
    "1970-1990", "1990-2000", "2000-2004",
    "2005", "2006", "2007",	"2008", "2009",
    "2010", "2011", "2012", "2013", "2014",
    "2015", "2016", "2017", "2018", "2019",
    "2020", "2021",
    "2022 Jan to June", "2022 June to Oct", "2022 November to December")) {
    
    cat(sprintf("Processing %s\n", subdir))
    dat <- read.csv(
      file = sprintf("%s/CSV/%s/UM_OPH_VISUAL_FIELD.csv", xmlroot, subdir),
      colClasses = c(MRN = "character", MRN0 = "character"),
      row.names = 1)
    # names(dat)
    cat(sprintf("%6d rows read\n", nrow(dat)))
    
    # get PAT_MRN from MRN
    dat1 <- merge(dat, xwalk1, by.x = "MRN", by.y = "PAT_MRN", all.x = TRUE)
    if (nrow(dat1) != nrow(dat)) stop("Incorrect match process.")
    cat(sprintf("%6d tokens missing of %6d\n", sum(is.na(dat1$PAT_MRN_T)), nrow(dat1)))
    
    # shift test date
    dat2 <- merge(dat1, xwalk2, by.x = "MRN", by.y = "PAT_MRN", all.x = TRUE)
    if (nrow(dat2) != nrow(dat1)) stop("Incorrect match process.")
    cat(sprintf("%6d shifts missing of %6d\n", sum(is.na(dat2$SHIFT_NUM)), nrow(dat2)))
    # names(dat2)
    
    # shift test date (to NA if no SHIFT_NUM)
    substr(dat2$TestDateTime, 1, 10) <- as.character(as.Date(dat2$TestDateTime) + dat2$SHIFT_NUM)
    cat(sprintf("%6d DateTimes missing of %6d\n", sum(is.na(dat2$TestDateTime)), nrow(dat2)))
    
    dat2[, c("Name", "MRN0", "MRN", "DOB", "Age", "Sex",
             "Institution", "TestDate", "TestTime",
             "SHIFT_NUM")] <- NULL
    names(dat2)[which(names(dat2) == "PAT_MRN_T")] <- "PAT_MRN"
    dat2$SITE_ID <- "799422"
    
    dat2 <- dat2[, c(
      "SITE_ID", "PAT_MRN", 
      setdiff(names(dat2), c("SITE_ID", "PAT_MRN")))]
    names(dat2)
    
    if (!dir.exists(sprintf("%s/CSV_Tokenized/%s", xmlroot, subdir))) {
      if (!dir.create(sprintf("%s/CSV_Tokenized/%s", xmlroot, subdir))) {
        stop("Unable to create output directory")
      }
    }
    
    write.csv(
      dat2, 
      file = sprintf("%s/CSV_Tokenized/%s/SOURCE_UM_OPH_VISUAL_FIELD.csv", xmlroot, subdir),
      row.names = TRUE, na = "")
  }
}