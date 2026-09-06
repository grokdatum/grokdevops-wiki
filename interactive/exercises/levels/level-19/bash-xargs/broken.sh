#!/bin/bash
# This script processes files that may have spaces in their names

WORKDIR="/tmp/xargs_test_$$"
mkdir -p "$WORKDIR"

# Create test files with spaces in names
echo "data1" > "$WORKDIR/my file 1.txt"
echo "data2" > "$WORKDIR/my file 2.txt"
echo "data3" > "$WORKDIR/report final.txt"

# BUG: xargs splits on whitespace, breaking filenames with spaces
COUNT=$(find "$WORKDIR" -name "*.txt" | xargs wc -l | tail -1 | awk '{print $1}')

echo "SUCCESS: Total lines: $COUNT"
rm -rf "$WORKDIR"
