# helper functions to de-identify imaging metadata for the SOURCE

#' De-identify tabular imaging metadata files
#'
#' De-identifies tabular metadata exports by replacing identifiers and
#' shifting date/time variables according to token and date-shift
#' crosswalk files.
#'
#' The function scans a source directory for files matching a regular
#' expression pattern, applies de-identification via \code{fileDeID()},
#' and writes the processed files to an output directory.
#'
#' @param source.dir Character string. Directory containing metadata files
#'   to be de-identified.
#'
#' @param tokenfile Character string. Path to the token crosswalk file
#'   mapping original identifiers (e.g., MRNs) to de-identified tokens.
#'   See \code{\link{loadxwalks}}.
#'
#' @param dateshiftfile Character string. Path to the date-shift crosswalk
#'   file defining patient-specific date offsets. See \code{\link{loadxwalks}}.
#'
#' @param filename.pattern Character string. Regular expression used to
#'   select files in \code{source.dir} for processing.
#'
#' @param deident.dir Character string. Output directory for de-identified
#'   files. Defaults to a subdirectory named \code{"deidentified"} within
#'   \code{source.dir}. Created if it does not exist.
#'
#' @param overwrite Logical scalar. If \code{FALSE} the function
#'   stops with an error if an output file already exists. If \code{TRUE}
#'   (default), existing files are overwritten.
#'
#' @param verbose Logical scalar. If \code{TRUE} (default), progress
#'   messages are printed during processing.
#'
#' @param ... Additional arguments passed to \code{fileDeID()} controlling
#'   device-specific behavior such as:
#'   \itemize{
#'     \item Identifier variable name
#'     \item Date variables to shift
#'     \item Date/time formats
#'     \item Variables to remove
#'     \item Input and output separators
#'   }
#'
#' @details
#' De-identification is performed by:
#' \enumerate{
#'   \item Loading identifier and date-shift crosswalks using
#'         \code{loadxwalks()}.
#'   \item Selecting files in \code{source.dir} matching
#'         \code{filename.pattern}.
#'   \item Applying \code{fileDeID()} to each file.
#'   \item Writing results to \code{deident.dir}.
#' }
#'
#' Date and datetime shifting behavior depends on arguments passed via
#' \code{...}. Device-specific wrapper functions such as
#' \code{deidentify.spectralis.raw()} provide predefined configurations.
#'
#' @return
#' Invisibly returns a character vector containing the full paths of the
#' generated de-identified files.
#'
#' @seealso
#' \code{\link{fileDeID}},
#' \code{\link{deidentify.spectralis.raw}},
#' \code{\link{deidentify.spectralis.pdf}},
#' \code{\link{deidentify.cirrus}},
#' \code{\link{deidentify.hfa}}
#'
#' @export
deidentify.metadata <- function(
	source.dir,
	tokenfile,
	dateshiftfile,
	filename.pattern,
	deident.dir = file.path(source.dir, "deidentified"),
	overwrite = TRUE,
	verbose = TRUE,
	...
) {

	if (!dir.exists(source.dir)) {
		stop("source.dir does not exist: ", source.dir)
	}

	if (!file.exists(tokenfile)) {
		stop("tokenfile does not exist: ", tokenfile)
	}

	if (!file.exists(dateshiftfile)) {
		stop("dateshiftfile does not exist: ", dateshiftfile)
	}

	sourcefiles <- dir(
		path = source.dir,
		pattern = filename.pattern,
		full.names = TRUE
	)

	if (length(sourcefiles) == 0) {
		warning("No files matched pattern in source.dir")
		return(invisible(character(0)))
	}

	if (!dir.exists(deident.dir)) {
		dir.create(deident.dir, recursive = TRUE)
	}

	xwalk <- loadxwalks(
		tokenfile = tokenfile,
		dateshiftfile = dateshiftfile,
		compare_mrn_numeric = FALSE
	)

	outfiles <- vapply(sourcefiles, function(sourcefile) {

		outfile <- file.path(deident.dir, basename(sourcefile))

		if (!overwrite && file.exists(outfile)) {
			stop("Output file already exists: ", outfile,
					 ". Set overwrite = TRUE to overwrite.")
		}

		if (isTRUE(verbose)) {
			message("De-identifying: ", sourcefile)
		}

		fileDeID(
			filetodeid = sourcefile,
			xwalk = xwalk,
			outputfile = outfile,
			verbose = if (isTRUE(verbose)) 2 else 0,
			...
		)

		outfile

	}, character(1))

	invisible(outfiles)
}


#' De-identify Spectralis raw metadata exports
#'
#' Convenience wrapper around \link{deidentify.metadata} for
#' Spectralis raw metadata files (typically named
#' \code{"metadata.tsv"}).
#'
#' This function applies a predefined configuration appropriate for
#' Spectralis raw exports, including identifier handling, date shifting,
#' and removal of name and file reference columns.
#'
#' @inheritParams deidentify.metadata
#'
#' @details
#' Internally sets:
#' \itemize{
#'   \item \code{filename.pattern = "^metadata\\.tsv$"}
#'   \item Spectralis-specific date and datetime formats
#'   \item Removal of personal name and file path variables
#' }
#'
#' @return
#' Invisibly returns a character vector of generated de-identified files.
#'
#' @seealso
#' \link{deidentify.metadata}
#'
#' @export
deidentify.spectralis.raw <- function(
	source.dir,
	tokenfile,
	dateshiftfile,
	deident.dir = file.path(source.dir, "deidentified"),
	overwrite = FALSE,
	verbose = TRUE
) {

	deidentify.metadata(
		source.dir = source.dir,
		tokenfile = tokenfile,
		dateshiftfile = dateshiftfile,
		filename.pattern = "^metadata\\.tsv$",
		deident.dir = deident.dir,
		overwrite = overwrite,
		verbose = verbose,
		fd_varname_mrn = "id",
		datevariablestodateshift = "birthdate",
		dateformat = "%Y%m%d",
		datetimevariablestodateshift = "timeoftest",
		datetimeformat = "%y%m%d%H%M%S",
		epochvariablestodateshift = "timeoftestEpoch",
		variablestoremove = c(
			"FamilyName", "GivenName", "MiddleName",
			"NamePrefix", "NameSuffix",
			"datadir", "SLOfilename", "OCTfilename"
		),
		separator = "\t",
		separator_out = "\t"
	)
}


#' De-identify Spectralis PDF-derived data exports
#'
#' Convenience wrapper around \link{deidentify.metadata} for
#' Spectralis data extracted from PDF reports (typically files
#' matching \code{"^pdf_.+\\.tsv$"}).
#'
#' Applies predefined column removal and date-shifting settings
#' appropriate for PDF-derived metadata tables.
#'
#' @inheritParams deidentify.metadata
#'
#' @details
#' Internally sets:
#' \itemize{
#'   \item \code{filename.pattern = "^pdf_.+\\.tsv$"}
#'   \item Date variables \code{"dob"} and \code{"TestDate"}
#'   \item Removal of \code{"FileName"} column
#' }
#'
#' @return
#' Invisibly returns a character vector of generated de-identified files.
#'
#' @seealso
#' \link{deidentify.metadata}
#'
#' @export
deidentify.spectralis.pdf <- function(
	source.dir,
	tokenfile,
	dateshiftfile,
	deident.dir = file.path(source.dir, "deidentified"),
	overwrite = FALSE,
	verbose = TRUE
) {

	deidentify.metadata(
		source.dir = source.dir,
		tokenfile = tokenfile,
		dateshiftfile = dateshiftfile,
		filename.pattern = "^pdf_.+\\.tsv$",
		deident.dir = deident.dir,
		overwrite = overwrite,
		verbose = verbose,
		fd_varname_mrn = "id",
		datevariablestodateshift = c("dob", "TestDate"),
		dateformat = "%Y%m%d",
		variablestoremove = "FileName",
		separator = "\t",
		separator_out = "\t"
	)
}


#' De-identify Cirrus metadata exports
#'
#' Convenience wrapper around \link{deidentify.metadata} for
#' Cirrus metadata files (typically matching
#' \code{"^metadata_.+\\.tsv$"}).
#'
#' Applies predefined identifier, date-shifting, and column removal
#' settings appropriate for Cirrus exports.
#'
#' @inheritParams deidentify.metadata
#'
#' @details
#' Internally sets:
#' \itemize{
#'   \item \code{filename.pattern = "^metadata_.+\\.tsv$"}
#'   \item Cirrus-specific datetime format
#'   \item Removal of scan and file reference variables
#' }
#'
#' @return
#' Invisibly returns a character vector of generated de-identified files.
#'
#' @seealso
#' \link{deidentify.metadata}
#'
#' @export
deidentify.cirrus <- function(
	source.dir,
	tokenfile,
	dateshiftfile,
	deident.dir = file.path(source.dir, "deidentified"),
	overwrite = FALSE,
	verbose = TRUE
) {

	deidentify.metadata(
		source.dir = source.dir,
		tokenfile = tokenfile,
		dateshiftfile = dateshiftfile,
		filename.pattern = "^metadata_.+\\.tsv$",
		deident.dir = deident.dir,
		overwrite = overwrite,
		verbose = verbose,
		fd_varname_mrn = "id",
		datevariablestodateshift = "birthdate",
		dateformat = "%Y%m%d",
		datetimevariablestodateshift = "timeoftest",
		datetimeformat = "%y%m%d%H%M%S",
		variablestoremove = c(
			"datadir", "scanid", "refid", "filenameRawData"
		),
		separator = "\t",
		separator_out = "\t"
	)
}


#' De-identify HFA data exports
#'
#' Convenience wrapper around \link{deidentify.metadata} for
#' HFA CSV data files.
#'
#' Applies predefined date and datetime handling appropriate for
#' HFA exports.
#'
#' @inheritParams deidentify.metadata
#'
#' @details
#' Internally sets:
#' \itemize{
#'   \item \code{filename.pattern = \".+\\.csv$\"}
#'   \item HFA-specific datetime format (\code{\"%y%m%d%H%M\"})
#' }
#' }
#'
#' @return
#' Invisibly returns a character vector of generated de-identified files.
#'
#' @seealso
#' \link{deidentify.metadata}
#'
#' @export
deidentify.hfa <- function(
	source.dir,
	tokenfile,
	dateshiftfile,
	deident.dir = file.path(source.dir, "deidentified"),
	overwrite = FALSE,
	verbose = TRUE
) {

	deidentify.metadata(
		source.dir = source.dir,
		tokenfile = tokenfile,
		dateshiftfile = dateshiftfile,
		filename.pattern = ".+\\.csv$",
		deident.dir = deident.dir,
		overwrite = overwrite,
		verbose = verbose,
		fd_varname_mrn = "id",
		datevariablestodateshift = "birthdate",
		dateformat = "%Y%m%d",
		datetimevariablestodateshift = "timeoftest",
		datetimeformat = "%y%m%d%H%M",
		epochvariablestodateshift = "timeoftestEpoch"
	)
}
