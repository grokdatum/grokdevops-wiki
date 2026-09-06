#!/bin/bash
# This script processes files that may have spaces in their names

WORKDIR="/tmp/xargs_test_$$"
mkdir -p "$WORKDIR"

# Create test files with spaces in names
echo "data1" > "$WORKDIR/my file 1.txt"
echo "data2" > "$WORKDIR/my file 2.txt"
echo "data3" > "$WORKDIR/report final.txt"

# Fixed: Use -print0 and xargs -0 for null-delimited filenames
COUNT=$(find "$WORKDIR" -name "*.txt" -print0 | xargs -0 wc -l | tail -1 | awk '{print $1}')

echo "SUCCESS: Total lines: $COUNT"
rm -rf "$WORKDIR"
