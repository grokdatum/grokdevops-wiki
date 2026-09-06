#!/bin/bash
# This script creates temp files and should clean them up on exit

TMPFILE="/tmp/trap_test_$$.dat"
echo "important data" > "$TMPFILE"

cleanup() {
    rm -f "$TMPFILE"
    echo "Cleanup done"
}

# BUG: Wrong trap syntax - should quote the command/function name, and signal is wrong
trap "cleanup; exit" QUIT

echo "Processing..."
echo "SUCCESS: Processing complete"

# Simulate normal exit - cleanup should run
exit 0
