#!/bin/bash
# This script finds unique error types from a log

ERRORS="ConnectionError
TimeoutError
ConnectionError
DiskError
TimeoutError
ConnectionError
DiskError"

# BUG: uniq only removes adjacent duplicates - data must be sorted first
UNIQUE=$(echo "$ERRORS" | uniq)
COUNT=$(echo "$UNIQUE" | wc -l)

echo "Unique errors:"
echo "$UNIQUE"
echo "SUCCESS: Found $COUNT unique error types"
