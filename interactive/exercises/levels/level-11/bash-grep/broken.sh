#!/bin/bash
# This script counts how many lines in a log contain "ERROR"

LOG="/tmp/grep_test_$$.log"
cat > "$LOG" << 'LOGDATA'
2024-01-01 INFO Starting service
2024-01-01 ERROR Connection refused
2024-01-01 INFO Retrying
2024-01-01 ERROR Timeout reached
2024-01-01 ERROR Disk full
2024-01-01 INFO Service stopped
LOGDATA

# BUG: -l lists filenames with matches, not count of matches
COUNT=$(grep -l "ERROR" "$LOG")

echo "SUCCESS: Found $COUNT error lines"
rm -f "$LOG"
