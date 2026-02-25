# De-identify tabular imaging metadata files

De-identifies tabular metadata exports by replacing identifiers and
shifting date/time variables according to token and date-shift crosswalk
files.

## Usage

``` r
deidentify.metadata(
  source.dir,
  tokenfile,
  dateshiftfile,
  filename.pattern,
  deident.dir = file.path(source.dir, "deidentified"),
  overwrite = TRUE,
  verbose = TRUE,
  ...
)
```

## Arguments

- source.dir:

  Character string. Directory containing metadata files to be
  de-identified.

- tokenfile:

  Character string. Path to the token crosswalk file mapping original
  identifiers (e.g., MRNs) to de-identified tokens. See
  [`loadxwalks`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/loadxwalks.md).

- dateshiftfile:

  Character string. Path to the date-shift crosswalk file defining
  patient-specific date offsets. See
  [`loadxwalks`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/loadxwalks.md).

- filename.pattern:

  Character string. Regular expression used to select files in
  `source.dir` for processing.

- deident.dir:

  Character string. Output directory for de-identified files. Defaults
  to a subdirectory named `"deidentified"` within `source.dir`. Created
  if it does not exist.

- overwrite:

  Logical scalar. If `FALSE` the function stops with an error if an
  output file already exists. If `TRUE` (default), existing files are
  overwritten.

- verbose:

  Logical scalar. If `TRUE` (default), progress messages are printed
  during processing.

- ...:

  Additional arguments passed to
  [`fileDeID()`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/fileDeID.md)
  controlling device-specific behavior such as:

  - Identifier variable name

  - Date variables to shift

  - Date/time formats

  - Variables to remove

  - Input and output separators

## Value

Invisibly returns a character vector containing the full paths of the
generated de-identified files.

## Details

The function scans a source directory for files matching a regular
expression pattern, applies de-identification via
[`fileDeID()`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/fileDeID.md),
and writes the processed files to an output directory.

De-identification is performed by:

1.  Loading identifier and date-shift crosswalks using
    [`loadxwalks()`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/loadxwalks.md).

2.  Selecting files in `source.dir` matching `filename.pattern`.

3.  Applying
    [`fileDeID()`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/fileDeID.md)
    to each file.

4.  Writing results to `deident.dir`.

Date and datetime shifting behavior depends on arguments passed via
`...`. Device-specific wrapper functions such as
[`deidentify.spectralis.raw()`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/deidentify.spectralis.raw.md)
provide predefined configurations.

## See also

[`fileDeID`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/fileDeID.md),
[`deidentify.spectralis.raw`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/deidentify.spectralis.raw.md),
[`deidentify.spectralis.pdf`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/deidentify.spectralis.pdf.md),
[`deidentify.cirrus`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/deidentify.cirrus.md),
[`deidentify.hfa`](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/deidentify.hfa.md)
