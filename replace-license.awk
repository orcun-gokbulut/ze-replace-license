#!/usr/bin/gawk -f

# UTILITY FUNCTIONS
#################################################

function basename(file) 
{
    sub(".*/", "", file)
    return file
}

function _exit(code)
{
    exitCode = code
    exit code
}

function readfile(file,     tmp, save_rs)
{
    save_rs = RS
    RS = "^$"
    
    getline tmp < file
    close(file)

    RS = save_rs

    sub(/%SOURCE_FILE_NAME%/, basename(FILENAME), tmp)
    
    return tmp
}
 
function licenseTagStart(version, tagStart)
{
    if (verbose)
        print "[Info] Found " tagStart " tag. Version: " a[1] > "/dev/stderr"

    fileLicenseVersion = version

    licenseStart = 1
    licenseStartTag = $0

    next
}

function licenseTagEnd(tagStart, tagEng)
{
    if (verbose)
        print "[Info] Found " tagEng " tag." > "/dev/stderr"

    if (licenseStart != 1)
    {
        print "[Error] " tagEng " found but " tagStart " not found. File: \"" FILENAME "\"" > "/dev/stderr"
        if (fixFishy)
        {
            print "[Warning] Fixing fishy. Non-existing START tag. File: \"" FILENAME "\"" > "/dev/stderr"

            buffer=""
            licenseStart=1

        }
        else
        {
            _exit(1)
        }
    }

    licenseEnd = 1
    next
}


# INITIALIZATION
#################################################

BEGIN {
    quiet = 0
    verbose = 0
    addMissing = 0
    exitCode = -1
    fixFishy=0
    licenseVersion = "1.0"
    licenseFile = "license-header.txt"
}

BEGINFILE {
    if (system("test -f " $licenseFile) != 0)
    {
        print "[Error] License file '" licenseFile "' not found. File \"" FILENAME "\"" > "/dev/stderr"
        _exit(1)
    }

    licenseStart = 0
    licenseEnd = 0
    buffer = ""
    foundPreprocessor = 0

    if (verbose)
        print "[Info] Reading license file '" licenseFile "'..." > "/dev/stderr"
    
    fileLicenseVersion = ""
    license = readfile(licenseFile)

    if (!quiet)
        print "[Info] Processing file '" FILENAME "'..." > "/dev/stderr"
} 


# START TAGS
#################################################
/^\xef\xbb\xbf/ {
    print "[Info] UTF-8 BOM detected. Removing..."  > "/dev/stderr"
    sub(/^\xef\xbb\xbf/, "");
}

match($0, /^\s*\/\/\s*ZE_SOURCE_PROCESSOR_START\s*\(\s*License\s*,\s*([0-9]+\.[0-9]+)\s*\)\s*$/, versionMatch) {
    licenseTagStart(versionMatch[1], "ZE_SOURCE_PROCESSOR_START")
}

/^\s*\/\*\s*ZE_POST_PROCESSOR_START\s*\(\s*License\s*\)\s*\*\/\s*$/ {
    licenseTagStart("", "ZE_POST_PROCESSOR_START")
}

/\/\*ZEHEADER_START\*\// {
    licenseTagStart("", "FISHY_START" "FISHY_END")
}


# END TAGS
#################################################

/^\s*\/\/\s*ZE_SOURCE_PROCESSOR_END\s*\(\s*\)\s*$/ {
    licenseTagEnd("ZE_SOURCE_PROCESSOR_START", "ZE_SOURCE_PROCESSOR_END")
}

/^\s*\/\*\s*ZE_POST_PROCESSOR_END\s*\(\s*\)\s*\*\/\s*$/ {
    licenseTagEnd("ZE_POST_PROCESSOR_START", "ZE_POST_PROCESSOR_END")
}

/\/\*ZEHEADER_END\*\// {
    licenseTagEnd("ZEHEADER_START", "ZEHEADER_END")
}

/^(#ifndef|#include|#pragma)/ {
    if (licenseStart == 1 && licenseEnd != 1 && foundPreprocessor == 0 && fixFishy == 1)
    {
        print "[Warning] Fixing fishy. Non-existing END tag. File: \"" FILENAME "\"" > "/dev/stderr"
        buffer = buffer $0 "\n"
        foundPreprocessor = 1
        licenseTagEnd()
    }
}


# PROBLEM DETECTION
#################################################

# Missing Start Tag
# Missing End Tag


# COPY REGULAR LINES
#################################################

{ 
    if (!licenseStart || licenseEnd)
        buffer = buffer $0 "\n"
}


# OUTPUT
#################################################

END {
    if (exitCode != -1)
        exit exitCode

    if (!licenseStart && !addMissing)
    {
        print "[Error] License START tag not found. File: \"" FILENAME "\"" > "/dev/stderr"
        _exit(2)
    }

    if (licenseStart && !licenseEnd)
    {
        print "[Error] License END tag not found. File: \"" FILENAME "\"" > "/dev/stderr"
        _exit(3)
    }

    if (!licenseStart)
    {
        if (!quiet)
            print "[Info] License not found adding license. File: \"" FILENAME "\"" > "/dev/stderr"

        if (substr(buffer, 0, 1) != "\n" && substr(buffer, 0, 2) != "\r\n")
            buffer = "\n" buffer
    }
    else
    {
        if (licenseVersion != fileLicenseVersion)
            print "[Warning] Diffrent license version found. Replacing license. Actual Version: \"" fileLicenseVersion "\" Expected Version: \"" licenseVersion "\" File: \"" FILENAME "\"" > "/dev/stderr"
    }

    printf "//ZE_SOURCE_PROCESSOR_START(License, %s)\n%s\n//ZE_SOURCE_PROCESSOR_END()\n%s", licenseVersion, license, buffer > FILENAME

    if (verbose)
        print "[Info] Processing done. File \"" FILENAME "\"" > "/dev/stderr"

    _exit(0)
}
