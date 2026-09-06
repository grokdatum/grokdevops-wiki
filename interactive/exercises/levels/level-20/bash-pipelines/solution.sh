#!/bin/bash
# This script captures both stdout and stderr from a command into a log

LOGFILE="/tmp/pipeline_test_$$.log"

# Generate both stdout and stderr
generate_output() {
    echo "INFO: Starting process"
    echo "ERROR: Something went wrong" >&2
    echo "INFO: Process complete"
    echo "ERROR: Cleanup failed" >&2
}

# Fixed: Redirect stdout to file first, THEN redirect stderr to stdout
generate_output > "$LOGFILE" 2>&1

LINE_COUNT=$(wc -l < "$LOGFILE")
HAS_ERRORS=$(grep -c "ERROR" "$LOGFILE")

echo "SUCCESS: Captured $LINE_COUNT lines, including $HAS_ERRORS errors"
rm -f "$LOGFILE"
