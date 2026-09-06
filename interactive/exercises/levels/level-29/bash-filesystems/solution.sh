#!/bin/bash
# This script finds all directories in a path that are older than 7 days

SEARCH_DIR="/tmp/find_test_$$"
mkdir -p "$SEARCH_DIR/logs" "$SEARCH_DIR/cache" "$SEARCH_DIR/data"
touch "$SEARCH_DIR/file1.txt" "$SEARCH_DIR/file2.txt"

# Fixed: Use -type d to find directories
DIR_COUNT=$(find "$SEARCH_DIR" -maxdepth 1 -type d | grep -v "^${SEARCH_DIR}$" | wc -l)

echo "Found $DIR_COUNT directories in $SEARCH_DIR"

# Verify we found directories (should be 3: logs, cache, data)
ACTUAL_DIRS=$(find "$SEARCH_DIR" -maxdepth 1 -type d | grep -v "^${SEARCH_DIR}$" | wc -l)
if [ "$DIR_COUNT" -eq "$ACTUAL_DIRS" ]; then
    echo "SUCCESS: Correctly found $DIR_COUNT directories"
else
    echo "FAIL: Expected $ACTUAL_DIRS directories, found $DIR_COUNT"
fi

rm -rf "$SEARCH_DIR"
