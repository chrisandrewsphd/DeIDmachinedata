# helper functions to de-identify imaging metadata for the SOURCE;
# work in progress, not yet ready


deidentify.metadata <- function(
	source.dir,
	tokenfile,
	dateshiftfile,
	filename.pattern,
	deident.dir = file.path(source.dir, "deidentified"),
	...)
{
	sourcefiles <- dir(path=source.dir, pattern=filename.pattern, full.names=TRUE)
	
	if (length(sourcefiles) == 0) {
        warning("No files matched pattern in source.dir")
        return(invisible(NULL))
    }
	
	if(!dir.exists(deident.dir))
		dir.create(deident.dir, recursive = TRUE)
	
	xwalk <- loadxwalks(tokenfile = tokenfile, dateshiftfile = dateshiftfile, compare_mrn_numeric = FALSE)
	
	deid.file <- function(sourcefile)
	{
		cat("De-identifying", sourcefile, "...\n")
		outfile <- file.path(deident.dir, basename(sourcefile))
		fileDeID(
			filetodeid = sourcefile,
			xwalk = xwalk,
			outputfile = outfile,
			...)
		outfile
	}
	
	invisible(lapply(sourcefiles, deid.file))
	
}

deidentify.spectralis.raw <- function(...)
	deidentify.metadata(
		...,
		filename.pattern="^metadata\\.tsv$",
		fd_varname_mrn = "id",
		datevariablestodateshift = "birthdate",
		dateformat = "%Y%m%d",
		datetimevariablestodateshift = "timeoftest",
		datetimeformat = "%y%m%d%H%M%S",
		epochvariablestodateshift = "timeoftestEpoch",
		variablestoremove = c("FamilyName", "GivenName", "MiddleName", "NamePrefix", "NameSuffix", "datadir", "SLOfilename", "OCTfilename"),
		separator="\t",
		separator_out = "\t")


deidentify.spectralis.pdf <- function(...)
	deidentify.metadata(
		...,
		filename.pattern="^pdf_.+\\.tsv$",
		fd_varname_mrn = "id",
		datevariablestodateshift = c("dob", "TestDate"),
		dateformat = "%Y%m%d",
		variablestoremove = c("FileName"),
		separator="\t",
		separator_out = "\t")



deidentify.cirrus <- function(...)
	deidentify.metadata(
		...,
		filename.pattern="^metadata_.+\\.tsv$",
		fd_varname_mrn = "id",
		datevariablestodateshift = "birthdate",
		dateformat = "%Y%m%d",
		datetimevariablestodateshift = "timeoftest",
		datetimeformat = "%y%m%d%H%M%S",
		variablestoremove = c("datadir", "scanid", "refid", "filenameRawData"),
		separator="\t",
		separator_out = "\t")


deidentify.hfa <- function(...)
	deidentify.metadata(
		...,
		filename.pattern=".+\\.csv$",
		fd_varname_mrn = "id",
		datevariablestodateshift = "birthdate",
		dateformat = "%Y%m%d",
		datetimevariablestodateshift = "timeoftest",
		datetimeformat = "%y%m%d%H%M",
		epochvariablestodateshift = "timeoftestEpoch")


