#!/bin/bash
# This script finds unique error types from a log

ERRORS="ConnectionError
TimeoutError
ConnectionError
DiskError
TimeoutError
ConnectionError
DiskError"

# Fixed: Sort first, then uniq to remove all duplicates
UNIQUE=$(echo "$ERRORS" | sort | uniq)
COUNT=$(echo "$UNIQUE" | wc -l)

echo "Unique errors:"
echo "$UNIQUE"
echo "SUCCESS: Found $COUNT unique error types"
