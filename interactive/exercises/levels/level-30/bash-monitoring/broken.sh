#!/bin/bash
# This script checks system load average and alerts if too high

NUM_CPUS=4
THRESHOLD=2.0

# Simulated uptime output
UPTIME_OUTPUT=" 14:30:00 up 5 days,  3:22,  2 users,  load average: 6.50, 5.20, 4.80"

# BUG: Extracting the wrong metric - getting number of users instead of load average
LOAD=$(echo "$UPTIME_OUTPUT" | awk '{print $6}' | tr -d ',')

# Compare as integers (multiply by 100 to avoid float issues)
LOAD_INT=$(echo "$LOAD" | awk '{printf "%d", $1 * 100}')
THRESHOLD_INT=$(echo "$THRESHOLD" | awk '{printf "%d", $1 * 100}')

if [ "$LOAD_INT" -gt "$THRESHOLD_INT" ] 2>/dev/null; then
    PER_CPU=$(echo "$LOAD $NUM_CPUS" | awk '{printf "%.2f", $1/$2}')
    echo "SUCCESS: Load average $LOAD (${PER_CPU} per CPU) exceeds threshold $THRESHOLD"
else
    echo "FAIL: Could not parse load average correctly (got: $LOAD)"
fi
