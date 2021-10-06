#!/bin/bash
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR_PATH=$(dirname "$SCRIPT_PATH")

for file in $(find . -type f \( -name "*.cpp" -or -name "*.h" -or -name "*.hlsl" \) ) ; do
    $SCRIPT_DIR_PATH/replace-license.awk $@ $file
done;