# De-identify machine extraction data

This function is used to de-identify a flat file using a crosswalk (with
specific structure, see
[`loadxwalks()`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/loadxwalks.md)).
De-identification options include replacing a patient MRN by a tokenized
MRN (using the crosswalk), removing a column, 'blanking' a column (the
column remains in the dataset but all values are ""), and shifting a
date or datetime variable (using the crosswalk).

## Usage

``` r
fileDeID(
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
  verbose = 0L
)
```

## Arguments

- filetodeid:

  character. Filename of a single flat file to de-identify.

- fd_varname_mrn:

  character. Name of MRN variable in file to de-identify. Default is
  "PAT_MRN".

- variablestoremove:

  character vector. Names of variables in extraction file to remove.
  Default is `character(0)`, no variables to remove.

- variablestoblank:

  character vector. Names of variables in extraction file to blank. The
  variable will remain in the output file but will be ” for all rows.
  Default is `character(0)`, no variables to blank.

- datevariablestodateshift:

  character vector. Names of variables that are dates and should be
  date-shifted. Default is `character(0)`, no variables to shift.

- dateformat:

  character. Format of date variables in the extraction file. Default is
  "%Y-%m-%d" corresponding to 4-digit year, hyphen, 2-digit month,
  hyphen, 2-digit day.

- datetimevariablestodateshift:

  character vector. Names of variables that are datetimes and should be
  date-shifted. Default is `character(0)`, no variables to shift.

- datetimeformat:

  character. Format of datetime variables in the extraction file.
  Default is "%Y-%m-%d %H:%M:%OS" corresponding to 4-digit year, hyphen,
  2-digit month, hyphen, 2-digit day, space, 2-digit (24) hour, colon,
  2-digit minute, colon 2-digit second.

- separator:

  character. Field separator in filetodeid (input file). Default is
  `","`.

- separator_out:

  character. Field separator to use in outputfile. Default is `","`.

- xwalk:

  data.frame containing crosswalk information. Usually the output from
  [`loadxwalks()`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/loadxwalks.md).

- compare_mrn_numeric:

  logical. Should MRNs be compared as numeric variables? Usually this is
  a good idea because leading 0s may have been dropped during
  processing. Default is whatever was used to create xwalk, which is
  `TRUE` by default.

- outputfile:

  character. Name of file to write de-identified data. If `NULL` (the
  default) the data are not written, but only returned from the
  function. An additional option is the special value `"SOURCE_"`, which
  causes the output to be written to the same filename as the input but
  prepended with "SOURCE\_".

- usefread:

  If `TRUE` (default), use
  [`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html)
  and
  [`data.table::fwrite()`](https://rdrr.io/pkg/data.table/man/fwrite.html).
  If `FALSE`, use
  [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html) and
  [`utils::write.csv()`](https://rdrr.io/r/utils/write.table.html).
  `TRUE` is usually preferable as `FALSE` results in double quotes
  around almost all values when producing the output file.

- verbose:

  integer. Higher values produce more output to console. Default is 0,
  no output.

## Value

(invisibly) data.frame (even if `usefread == TRUE`) with variables
tokenized, date-shifted, removed, and/or blanked, as requested.

## Examples

``` r
dataloc <- system.file("extdata", package = "DeIDmachinedata")
fn1 <- sprintf("%s/xwalk1.csv", dataloc)
fn2 <- sprintf("%s/xwalk2.csv", dataloc)
xwalk <- loadxwalks(tokenfile = fn1, dateshiftfile = fn2)
fn3 <- sprintf("%s/pentacam_UCH.csv", dataloc)
deidfile <- fileDeID(
  filetodeid = fn3,
  fd_varname_mrn = "Pat-ID:",
  variablestoremove = c("Last Name:", "First Name:", "D.o.Birth:"),
  variablestoblank = "Exam Comment:",
  datevariablestodateshift = "Exam Date:",
  dateformat = "%m/%d/%Y",
  xwalk = xwalk,
  outputfile = NULL,
  verbose = 2)
#> Processing /home/runner/work/_temp/Library/DeIDmachinedata/extdata/pentacam_UCH.csv
#> /home/runner/work/_temp/Library/DeIDmachinedata/extdata/pentacam_UCH.csv Variable Names
#>  [1] "Last Name:"     "First Name:"    "Pat-ID:"        "D.o.Birth:"    
#>  [5] "Exam Date:"     "Exam Time:"     "Exam Eye:"      "Exam Type:"    
#>  [9] "Exam Comment:"  "Status"         "Error"          "Rf F (mm):"    
#> [13] "Rs F (mm):"     "Rh F (mm):"     "Rv F (mm):"     "K1 F (D):"     
#> [17] "K2 F (D):"      "Rm F (mm):"     "Km F (D):"      "Axis F (flat):"
#> [21] "Astig F (D):"   "R Per F (mm)"   "R Min (mm)"    
#> 3 rows read from /home/runner/work/_temp/Library/DeIDmachinedata/extdata/pentacam_UCH.csv
#>   Pat-ID: Exam Date: Exam Time: Exam Eye: Exam Type: Exam Comment:
#> 1       2   1/2/2020        123        OS      penta           PII
#> 2       2  1/31/2020        234        OS      penta           PII
#> 3       9 12/31/1999        321        OD      penta           PII
#>               Status Error Rf F (mm): Rs F (mm): Rh F (mm): Rv F (mm):
#> 1               Good  None        9.3       <NA>        4.9       <NA>
#> 2 Good, Really Good!  None        9.3        8.7        4.1        6.3
#> 3                Bad   Yes          9        8.7       <NA>        6.3
#>   K1 F (D): K2 F (D): Rm F (mm): Km F (D): Axis F (flat): Astig F (D):
#> 1        50        60        8.1        35             75           10
#> 2        40        50          8        30             80           30
#> 3         0         0        7.9        10             20           30
#>   R Per F (mm) R Min (mm)
#> 1            5          9
#> 2          5.5         10
#> 3          1.1          6
#> Summary of MRN matching index
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.    NA's 
#>       2       2       2       2       2       2       1 
#> Number of patients with each number of test (original MRN)
#> 
#> 1 2 
#> 1 1 
#> Number of patients with each number of test (tokenized MRN)
#> 
#> 1 2 
#> 1 1 
#>      1 tokenized mrns missing of      3
#> Shifting Exam Date:
#> [1] "1/2/2020"   "1/31/2020"  "12/31/1999"
#> [1] "2020-01-06" "2020-02-04" NA          
deidfile # Note last test was on a person not in the crosswalk
#>   Pat-ID: Exam Date: Exam Time: Exam Eye: Exam Type: Exam Comment:
#> 1       b 2020-01-06        123        OS      penta          <NA>
#> 2       b 2020-02-04        234        OS      penta          <NA>
#> 3    <NA>       <NA>        321        OD      penta          <NA>
#>               Status Error Rf F (mm): Rs F (mm): Rh F (mm): Rv F (mm):
#> 1               Good  None        9.3       <NA>        4.9       <NA>
#> 2 Good, Really Good!  None        9.3        8.7        4.1        6.3
#> 3                Bad   Yes          9        8.7       <NA>        6.3
#>   K1 F (D): K2 F (D): Rm F (mm): Km F (D): Axis F (flat): Astig F (D):
#> 1        50        60        8.1        35             75           10
#> 2        40        50          8        30             80           30
#> 3         0         0        7.9        10             20           30
#>   R Per F (mm) R Min (mm)
#> 1            5          9
#> 2          5.5         10
#> 3          1.1          6
```
