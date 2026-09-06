#!/bin/bash
# This script creates temp files and should clean them up on exit

TMPFILE="/tmp/trap_test_$$.dat"
echo "important data" > "$TMPFILE"

cleanup() {
    rm -f "$TMPFILE"
    echo "Cleanup done"
}

# Fixed: Trap on EXIT signal to run cleanup on any exit
trap cleanup EXIT

echo "Processing..."
echo "SUCCESS: Processing complete"

# Simulate normal exit - cleanup should run
exit 0
