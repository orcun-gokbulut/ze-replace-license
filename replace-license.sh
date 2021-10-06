#!/bin/bash

for file in $(find . -type f \( -name "*.cpp" -or -name "*.h" -or -name "*.hlsl" \) ) ; do
    ./replace-license.awk $@ $file
done;