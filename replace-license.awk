#!/usr/bin/gawk -f

function readfile(file,     tmp, save_rs)
{
    save_rs = RS
    RS = "^$"
    
    getline tmp < file
    close(file)

    RS = save_rs

    return substr(tmp, /%FILENAM%/, FILENAME)
}

BEGIN {
    quiet = 0
    verbose = 0
    addMissing = 0
    licenseVersion = "1.0"
    licenseFile = "license-header.txt"
}

BEGINFILE {
    if (system("test -f " $licenseFile) != 0)
    {
        print "[Error] License file '" licenseFile "' not found. File \"" FILENAME "\"" > "/dev/stderr"
        exit 1
    }

    licenseStart = 0
    licenseEnd = 0
    buffer = ""

    if (verbose)
        print "[Info] Reading license file '" licenseFile "'..." > "/dev/stderr"
    
    fileLicenseVersion = ""
    license = readfile(licenseFile)

    if (!quiet)
        print "[Info] Processing file '" FILENAME "'..." > "/dev/stderr"
} 

match($0, /^(?:\xef\xbb\xbf)?\s*\/\*\s*ZE_POST_PROCESSOR_START\s*\(\s*License\s*(?:,\s*([0-9]+\.[0-9]+)+\s*)?\)\s*\*\/\s*$/, a) {
    if (verbose)
        print "[Info] Found ZE_POST_PROCESSOR_START tag. Version: " a[1] > "/dev/stderr"

    fileLicenseVersion = a[1]

    licenseStart = 1
    licenseStartTag = $0

    next
}

/\/\*ZEHEADER_START\*\// {
    if (verbose)
        print "[Info] Found ZEHEADER_START tag." > "/dev/stderr"

    licenseStart = 1
    next
}

/^\s*\/\*\s*ZE_POST_PROCESSOR_END\s*\(\s*\)\s*\*\/\s*$/ {
    if (verbose)
        print "[Info] Found ZE_POST_PROCESSOR_END tag." > "/dev/stderr"

    if (licenseStart != 1)
    {
        print "[Error] ZE_POST_PROCESSOR_END found but ZE_POST_PROCESSOR_START not found. File: \"" FILENAME "\"" > "/dev/stderr"
        exit 1
    }

    licenseEnd = 1
    next
}

/\/\*ZEHEADER_END\*\// {
    if (verbose)
        print "[Info] Found ZE_HEADER_END tag." > "/dev/stderr"

    if (licenseStart != 1)
    {
        print "[Error] ZE_HEADER_END found but ZE_HEADER_START not found. File: \"" FILENAME "\"" > "/dev/stderr"
        exit 1
    }

    licenseEnd = 1
    next
}

{ 
    if (!licenseStart || licenseEnd)
        buffer = buffer $0 "\n"
}

END {   
    if (!licenseStart && !addMissing)
    {
        print "[Error] ZE_POST_PROCESSOR_START not found. File: \"" FILENAME "\"" > "/dev/stderr"
        exit 2
    }

    if (licenseStart && !licenseEnd)
    {
        print "[Error] ZE_POST_PROCESSOR_END not found. File: \"" FILENAME "\"" > "/dev/stderr"
        exit 3
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

    print "//ZE_SOURCE_PROCESSOR_START(License, " licenseVersion ")\n" license "\n" "//ZE_SOURCE_PROCESSOR_END()\n" buffer > FILENAME

    if (verbose)
        print "[Info] Processing done. File \"" FILENAME "\"" > "/dev/stderr"

    exit 0
}
