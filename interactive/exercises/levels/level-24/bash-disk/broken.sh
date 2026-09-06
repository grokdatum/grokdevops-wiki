#!/bin/bash
# This script checks if disk usage is above a threshold

# Simulated df output
DF_OUTPUT="Filesystem     1K-blocks    Used Available Use% Mounted on
/dev/sda1       50000000 35000000  15000000  70% /"

THRESHOLD=80

# BUG: Wrong column - $4 is Available, $5 is Use%
USAGE=$(echo "$DF_OUTPUT" | tail -1 | awk '{print $4}' | tr -d '%')

if [ "$USAGE" -lt "$THRESHOLD" ] 2>/dev/null; then
    echo "SUCCESS: Disk usage at ${USAGE}% (below ${THRESHOLD}% threshold)"
else
    echo "FAIL: Disk usage at ${USAGE}% exceeds ${THRESHOLD}% threshold"
fi
