# Load crosswalk(s) needed to de-identify machine data.

One crosswalk between mrns and tokenized mrns. Optionally (if any
date-shifting is to be done), a second file with mrns and date shift
variable

## Usage

``` r
loadxwalks(
  tokenfile = NULL,
  t_varname_mrn = "PAT_MRN",
  t_varname_mrn_token = "PAT_MRN_T",
  t_separator = ",",
  dateshiftfile = NULL,
  ds_varname_mrn = "PAT_MRN",
  ds_varname_dateshift = "SHIFT_NUM",
  ds_separator = ",",
  compare_mrn_numeric = TRUE,
  verbose = 0L
)
```

## Arguments

- tokenfile:

  character. Name of the mrn-tokenized mrn crosswalk file.

- t_varname_mrn:

  character. Name of the mrn variable in the token file. Default is
  "PAT_MRN".

- t_varname_mrn_token:

  character. Name of the tokenized mrn variable in the token file.
  Default is "PAT_MRN_T".

- t_separator:

  character. Field separator in tokenfile. Default is ",".

- dateshiftfile:

  character. Name of the mrn-date shift file.

- ds_varname_mrn:

  character. Name of the mrn variable in the date shift file. Default is
  "PAT_MRN".

- ds_varname_dateshift:

  character. Name of the date shift variable. Default is "SHIFT_NUM"

- ds_separator:

  character. Field separator in dateshiftfile. Default is ",".

- compare_mrn_numeric:

  logical. Should MRNs be compared as numeric variables? Usually this is
  a good idea because leading 0s may have been dropped during
  processing. Default is `TRUE`.

- verbose:

  integer. Higher values produce more output to console. Default is 0,
  no output.

## Value

A data.frame with columns PAT_MRN and PAT_MRN_T and, if dateshiftfile is
not NULL, SHIFT_NUM.

## Examples

``` r
dataloc <- system.file("extdata", package = "DeIDmachinedata")
fn1 <- sprintf("%s/xwalk1.csv", dataloc)
fn2 <- sprintf("%s/xwalk2.csv", dataloc)
xwalk <- loadxwalks(
  tokenfile = fn1,
  t_varname_mrn = "PAT_MRN",
  t_varname_mrn_token = "PAT_MRN_T",
  dateshiftfile = fn2,
  ds_varname_mrn = "PAT_MRN",
  ds_varname_dateshift = "SHIFT_NUM",
  compare_mrn_numeric = TRUE,
  verbose = 2)
#> Date Shift Crosswalk Variable Names
#> [1] "PAT_MRN"   "SHIFT_NUM"
#> 6 rows read from /home/runner/work/_temp/Library/DeIDmachinedata/extdata/xwalk2.csv
#>   PAT_MRN SHIFT_NUM
#> 1       1         3
#> 2       2         4
#> 3       3         5
#> 4       4         6
#> 5       5         7
#> 6       6         8
#> 6 unique rows in /home/runner/work/_temp/Library/DeIDmachinedata/extdata/xwalk2.csv
#> Token Crosswalk Variable Names
#> [1] "PAT_MRN"   "PAT_MRN_T"
#> 6 rows read from /home/runner/work/_temp/Library/DeIDmachinedata/extdata/xwalk1.csv
#>   PAT_MRN PAT_MRN_T
#> 1       1         a
#> 2       2         b
#> 3       3         c
#> 4       4         d
#> 5       5         e
#> 6       6         f
#> 6 unique rows in /home/runner/work/_temp/Library/DeIDmachinedata/extdata/xwalk1.csv
xwalk
#>   PAT_MRN PAT_MRN_T SHIFT_NUM
#> 1       1         a         3
#> 2       2         b         4
#> 3       3         c         5
#> 4       4         d         6
#> 5       5         e         7
#> 6       6         f         8
```
