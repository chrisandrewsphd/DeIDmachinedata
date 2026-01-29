# Deidentifying a Flat File

## Introduction

Ophthalmology uses many devices to monitor and record a patient’s visual
function. After extracting historical information from a device, the
data must be de-identified before submitting to SOURCE, the Sight
OUtcomes Research CollaborativE
(<https://www.sourcecollaborative.org/>).

The two functions in the package *DeIDmachinedata* can be used, along
with crosswalks provided by IT, to complete the data preparation. The
functions [loadxwalks()](#loadxwalks) and [fileDeID()](#filedeid) are
flexible enough to use with data extracted from many devices. The
examples is this vignette are for

- Pentacam
- Visual Field tests extracted with FORUM
- OCT scans from both CIRRUS and Spectrallis devices

The deidentification process involves

1.  replacing the patient’s actual MRN with a Tokenized MRN from
    Datavant’s linkage environment;

2.  shifting actual test dates by a patient-specific, SOURCE-determined
    number of days; and

3.  removing or blanking remaining PII information. Some examples of
    information to remove:

    1.  demographic information: date of birth, sex. These will already
        be available in the SOURCE patient file. No need to include them
        here
    2.  file information: some extractions indicate the location of the
        image data in a local file system. This is no use to SOURCE and
        could potentially reidentify the person.
    3.  service information: some extractions include the location of
        the test/scan. Not technically PII, but SOURCE masks site
        information so we would eliminate this column on our end if you
        didn’t.

### Before you start

Get two files from your IT. These files are the crosswalk between the
MRN and Tokenized MRN and the date-shift repository. These files are
created as part of the extraction from EPIC using code shared by the
SOURCE Data Architect Team.

Inspect the files you want to deidentify. You’ll need to determine

1.  the names of the variables that contain PII. The functions described
    here pass-through any columns not mentioned in the arguments from
    the input file to the output file.
2.  the format of any date or datetime variables to be shifted.

Install the R package “DeIDmachinedata” from GitHub:

``` r
install.packages("remotes")
remotes::install_github("chrisandrewsphd/DeIDmachinedata")
```

### After you finish

Of course, inspect the output files to confirm that you have properly
used the functions so that PII is no longer present. Then deliver the
files to SOURCE as you have delivered other files.

## Using DeIDmachinedata

Within R, load the R library:

``` r
library(DeIDmachinedata)
```

### loadxwalks()

loadxwalks() reads the two files provided by IT and creates a data.frame
in R. The input files can be in various formats, but the resulting
data.frame has the structure expected by [fileDeID()](#filedeid). This
function call is used regardless of the type of machine data to be
deidentified.

A typical call creates the data.frame “xwalk” in your environment:

``` r
xwalk <- loadxwalks(
  tokenfile = "mrncrosswalk.csv",
  dateshiftfile = "mrndateshift.csv")
```

You’ll need to specify the proper filenames. Supply the complete path if
they are not in the R working directory.

If you are interested in this object, you can run a few lines of R code

``` r
# OPTIONAL
ls() # list objects in the environment; will include "xwalk"

head(xwalk) # display the first 6 lines of xwalk
```

### fileDeID()

[fileDeID()](#filedeid) uses the crosswalk created by
[loadxwalks()](#loadxwalks) to perform the 3 items listed above on a
specified file. Specifically, the patient ID is replace by a tokenized
version, dates and datetimes are shifted, and other specified columns
are removed.

#### Pentacam

In our experience with Pentacam,

1.  the variable containing the patient’s MRN is “PAT-ID:”;
2.  the variable to be dateshifted is “Exam Date:” (with format
    “%Y%m%d”: 4-digit year, 2-digit month, and 2-digit day with no
    separators); and
3.  the variables to be removed are “Last Name:”, “First Name:”,
    “D.o.Birth:”, and “Exam Comment:”.

Thus, the standard call is

``` r
fileDeID(
  filetodeid = "pentacam.csv",
  fd_varname_mrn = "PAT-ID:",
  variablestoremove =
    c("Last Name:", "First Name:", "D.o.Birth:", "Exam Comment:"),
  datevariablestodateshift = "Exam Date:",
  dateformat = "%Y%m%d",
  xwalk = xwalk,
  outputfile = "SOURCE_")
```

It reads the file “pentacam.csv” and writes the file
“SOURCE_pentacam.csv”

A second Pentacam example where the variables are separated by
semicolons and the datetime format is ISO 8601
(<https://en.wikipedia.org/wiki/ISO_8601>)

``` r
fileDeID(
  filetodeid = "./Data/Example.csv",
  fd_varname_mrn = "Patient ID",
  variablestoremove =
    c("First name", "Last name", "National ID", "OD Comment", "OS Comment"),
  datetimevariablestodateshift = "Date / Time",
  datetimeformat = "%Y-%m-%dT%H:%M:%OS",
  separator = ";",
  xwalk = xwalk,
  outputfile = "./Data/Example_out.csv")
```

#### Visual Field (via FORUM)

The extraction process for visual fields often produces several flat
files corresponding to the several test formats (24-2, 10-2, etc.).
These can each be deidentified separately. Other than the input and
output filenames, the calls to fileDeID() are identical.

1.  the variable containing the patient’s MRN is usually “MRN” (but
    sometimes “MRN0”);
2.  the variable to be dateshifted is “TestDate” (with format “%Y%m%d”:
    4-digit year, 2-digit month, and 2-digit day with no separators) or
    “TestDateTime” (with format “%Y-%m-%d %H:%M:%OS”: 4-digit year,
    hypen, 2-digit month, hypen, 2-digit day, space, 2-digit hour
    (00-23), colon, 2-digit minute, colon, 2-digit second) or both; and
3.  the variables to be removed are “TestID”, “Name”, “MRN0” (or “MRN”),
    “DOB”, “Age”, “Sex”, and “Institution”.

Thus, the typical call is

``` r
fileDeID(
    filetodeid = "OPH_HVF.csv",
    fd_varname_mrn = "MRN",
    variablestoremove =
      c("TestID", "Name", "MRN0", "DOB", "Age", "Sex", "Institution"),
    datevariablestodateshift = "TestDate",
    dateformat = "%Y%m%d",
    datetimevariablestodateshift = "TestDateTime",
    datetimeformat = "%Y-%m-%d %H:%M:%OS",
    xwalk = xwalk,
    outputfile = "SOURCE_")
```

#### Spectralis OCT

I believe I have seen two different instances of data extracted from
Spectralis OCT. In the first instance, the variable containing the
patient’s MRN is “Patient.ID” and the variable to be dateshifted is
“OCT.Scan.Date”.

The second instance was using Elze’s software to extract from HEYEX.
Output is a tab-separated file.

1.  the variable containing the patient’s MRN is “id”;
2.  the variable to be date-shifted is “timeoftest”;
3.  the variables to remove are: “birthdate”, “male”, “timeoftestEpoch”,
    “age”, “datadir”, “deviceSerialNumber”, “softwareversion”, “hasSLO”,
    “hasOCT”, “SLOfilename”, “OCTfilename”;

The remaining variables that will be included in the file to transfer
are:

“righteye”, “seriesDescription”, “gaze”, “sloHorizontalFieldOfView”,
“slox”, “sloy”, “sloPixelspacingX”, “sloPixelspacingY”, “nbscans”,
“bscanx”, “bscany”, “duration”, “sliceThickness”,
“bscanPixelspacingWidth”, “bscanPixelspacingDepth”, “BScanWidthOrRadius”

``` r
ddd <- fileDeID(
  filetodeid = "./Data/metadata_spectralis.tsv",
  separator = "\t",
  fd_varname_mrn = "id",
  variablestoremove = c(
    "birthdate", "male", "timeoftestEpoch", "age",
    "datadir", "deviceSerialNumber",
    "softwareversion", "hasSLO", "hasOCT", "SLOfilename", "OCTfilename"),
  datetimevariablestodateshift = "timeoftest",
  datetimeformat = "%y%m%d%H%M%S",
  outputfile = "SOURCE_",
  xwalk = xwalk)
```

#### CIRRUS OCT

Our experience with CIRRUS OCT is limited to one instance. In that case,

1.  the variable containing the patient’s MRN is “PatientID”;
2.  the variable to be dateshifted is “StudyIDNUM” (with format
    “%Y%m%d”: 4-digit year, 2-digit month, and 2-digit day with no
    separators); and
3.  the variables to be removed are filename paths:
    “DicomFilePath_ODCube”, “DicomFilePath_GlaucOUAnalysis”, and
    “DicomFilePath_CorrespondingPDF”.

Thus, the function call is

``` r
fileDeID(
  filetodeid = "cirrus_oct_rnfl.csv",
  fd_varname_mrn = "PatientID",
  variablestoremove = c(
    "DicomFilePath_ODCube",
    "DicomFilePath_GlaucOUAnalysis",
    "DicomFilePath_CorrespondingPDF"),
  datevariablestodateshift = "StudyIDNUM",
  dateformat = "%Y%m%d",
  xwalk = xwalk,
  outputfile = "SOURCE_OCT_RNFL.csv")
```

#### HFA via Elze Software

1.  the variable containing the patient’s MRN is “id”; and
2.  the variable to be dateshifted is “examtesttime” (with format
    “%y%m%d%H%M”: 2-digit year, 2-digit month, 2-digit day; 2-digit
    hour; and 2-digit minute with no separators)
3.  several variables to remove including date of birth, sex, a second
    exam time variable that looks like an internal SAS-type
    representation of the datetime, institution, and two file paths.

#### CIRRUS via Elze Software

Output from a typical CIRRUS data extraction is a tab-separated file:

1.  the variable containing the patient’s MRN is “id”;
2.  the variable to be date-shifted is “timeoftest”;
3.  the variables to remove are: “male”, “age”, “birthdate”,
    “ethnicGroup”, “datadir”, “scanid”, “refid”, “cirrusserialnumber”,
    “cirrusdevicelabel”, “softwareversion”, “stationname”, and
    “filenameRawData”;

The remaining variables that will be included in the file to transfer
are:

“righteye”, “slox”, “sloy”, “nbscans”, “bscanx”, “bscany”,
“bscanPixelspacingWidth”, “bscanPixelspacingDepth”,
“bscanPixelspacingHeight”, “irisPixelspacingX”, “irisPixelspacingY”,
“sloPixelspacingX”, “sloPixelspacingY”, “zmotorpos”,
“polarizationslider”, “signalstrength”, “scanpatternoffsetx”,
“scanpatternoffsety”, “fixationposx”, “fixationposy”, “chinrestlocx”,
“chinrestlocy”, “chinrestlocz”, “ocularlenspos”, “duration”,
“rotationangletoref”, and “lsoquality”

``` r
ddd <- fileDeID(
  filetodeid = "./Data/metadata_5LineRaster.tsv",
  separator = "\t",
  fd_varname_mrn = "id",
  variablestoremove = c(
    "male", "age", "birthdate", "ethnicGroup",
    "datadir", "scanid", "refid", "cirrusserialnumber",
    "cirrusdevicelabel", "softwareversion", "stationname", "filenameRawData"),
  datetimevariablestodateshift = "timeoftest",
  datetimeformat = "%y%m%d%H%M%S",
  outputfile = "SOURCE_",
  xwalk = xwalk)
```

##### Macular Cube

1.  the variable containing the patient’s MRN is “id”;
2.  the variable to be date-shifted is “timeoftest”;
3.  the variables to remove are: “male”, “age”, “birthdate”,
    “ethnicGroup”, “datadir”, “scanid”, “refid”, “cirrusserialnumber”,
    “cirrusdevicelabel”, “softwareversion”, “stationname”,
    “filenameRawData”, “filenameAnalysis”;

The remaining variables that will be included in the file to transfer
are:

“righteye”,“slox”, “sloy”, “nbscans”, “bscanx”, “bscany”,
“bscanPixelspacingWidth”, “bscanPixelspacingDepth”,
“bscanPixelspacingHeight”, “irisPixelspacingX”, “irisPixelspacingY”,
“sloPixelspacingX”, “sloPixelspacingY”, “zmotorpos”,
“polarizationslider”, “signalstrength”, “scanpatternoffsetx”,
“scanpatternoffsety”, “fixationposx”, “fixationposy”, “chinrestlocx”,
“chinrestlocy”, “chinrestlocz”, “ocularlenspos”, “duration”,
“rotationangletoref”, “lsoquality”, “hasRaw”, “hasAnalysis”,
“hasGCCsegmentation”, “foveax”, “foveay”, “gccAverage”, “gccMinimum”,
“gccSectorST”, “gccSectorS”, “gccSectorSN”, “gccSectorIN”, “gccSectorI”,
“gccSectorIT”, “highresCentralBscanX”, “highresCentralBscanY”,
“highresCentralBscanPixelspacingWidth”,
“highresCentralBscanPixelspacingDepth”

``` r
fileDeID(
  filetodeid = "./Data/metadata_MacularCube.tsv",
  separator = "\t",
  fd_varname_mrn = "id",
  variablestoremove = c(
    "male", "age", "birthdate", "ethnicGroup",
    "datadir", "scanid", "refid", "cirrusserialnumber", "cirrusdevicelabel",
    "softwareversion", "stationname", "filenameRawData", "filenameAnalysis"),
  datetimevariablestodateshift = "timeoftest",
  datetimeformat = "%y%m%d%H%M%S",
  outputfile = "SOURCE_",
  xwalk = xwalk)
```

##### Ocular Disc Cube

1.  the variable containing the patient’s MRN is “id”;
2.  the variable to be date-shifted is “timeoftest”;
3.  the variables to remove are: “male”, “age”, “birthdate”,
    “ethnicGroup”, “datadir”, “scanid”, “refid”, “cirrusserialnumber”,
    “cirrusdevicelabel”, “softwareversion”, “stationname”,
    “filenameRawData”, “filenameAnalysis”;

The remaining variables that will be included in the file to transfer
are:

“righteye”, “slox”, “sloy”, “nbscans”, “bscanx”, “bscany”,
“bscanPixelspacingWidth”, “bscanPixelspacingDepth”,
“bscanPixelspacingHeight”, “irisPixelspacingX”, “irisPixelspacingY”,
“sloPixelspacingX”, “sloPixelspacingY”, “zmotorpos”,
“polarizationslider”, “signalstrength”, “scanpatternoffsetx”,
“scanpatternoffsety”, “fixationposx”, “fixationposy”, “chinrestlocx”,
“chinrestlocy”, “chinrestlocz”, “ocularlenspos”, “duration”,
“rotationangletoref”, “lsoquality”, “hasRaw”, “hasAnalysis”,
“clockhour1”, “clockhour2”, “clockhour3”, “clockhour4”, “clockhour5”,
“clockhour6”, “clockhour7”, “clockhour8”, “clockhour9”, “clockhour10”,
“clockhour11”, “clockhour12”, “quadrantt”, “quadrants”, “quadrantn”,
“quadranti”, “rimarea”, “discarea”, “avgcdratio”, “avgthickness”,
“verticalcdratio”, “cupvol”, “onhcenterx”, “onhcentery”

``` r
fileDeID(
  filetodeid = "./Data/metadata_OpticDiscCube.tsv",
  separator = "\t",
  fd_varname_mrn = "id",
  variablestoremove = c(
    "male", "age", "birthdate", "ethnicGroup",
    "datadir", "scanid", "refid", "cirrusserialnumber", "cirrusdevicelabel",
    "softwareversion", "stationname", "filenameRawData", "filenameAnalysis"),
  datetimevariablestodateshift = "timeoftest",
  datetimeformat = "%y%m%d%H%M%S",
  outputfile = "SOURCE_",
  xwalk = xwalk)
```

## Random Package Details

Both functions have help pages. Use ?loadxwalks and ?fileDeID to see the
complete list of arguments.

### Date Formats

If dates or datetimes are not stored in the common formats given in the
examples here, use [`?strptime`](https://rdrr.io/r/base/strptime.html)
to create the proper format for your data.
