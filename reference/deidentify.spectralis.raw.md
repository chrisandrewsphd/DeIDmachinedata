# De-identify Spectralis raw metadata exports

Convenience wrapper around
[deidentify.metadata](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/deidentify.metadata.md)
for Spectralis raw metadata files (typically named `"metadata.tsv"`).

## Usage

``` r
deidentify.spectralis.raw(
  source.dir,
  tokenfile,
  dateshiftfile,
  deident.dir = file.path(source.dir, "deidentified"),
  overwrite = FALSE,
  verbose = TRUE
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

## Value

Invisibly returns a character vector of generated de-identified files.

## Details

This function applies a predefined configuration appropriate for
Spectralis raw exports, including identifier handling, date shifting,
and removal of name and file reference columns.

Internally sets:

- `filename.pattern = "^metadata\.tsv$"`

- Spectralis-specific date and datetime formats

- Removal of personal name and file path variables

## See also

[deidentify.metadata](https://chrisandrewsphd.github.io/DeIDmachinedata/reference/deidentify.metadata.md)
