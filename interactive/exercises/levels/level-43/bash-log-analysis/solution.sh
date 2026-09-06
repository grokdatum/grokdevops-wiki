#!/bin/bash
# This script counts errors per hour from a log

LOG_DATA='2024-01-09 08:30:09 ERROR Database connection timeout
2024-01-09 08:45:12 INFO Request processed successfully
2024-01-09 09:00:00 ERROR API rate limit exceeded
2024-01-09 09:15:30 ERROR Disk space warning
2024-01-09 10:00:00 INFO Service restarted
2024-01-09 10:30:09 ERROR Memory threshold exceeded'

TARGET_HOUR="09"

# Fixed: Anchor pattern to match hour position " HH:" (space before, colon after)
HOUR_ERRORS=$(echo "$LOG_DATA" | grep " ${TARGET_HOUR}:" | grep -c "ERROR")

if [ "$HOUR_ERRORS" -eq 2 ]; then
    echo "SUCCESS: Found $HOUR_ERRORS errors in hour $TARGET_HOUR"
else
    echo "FAIL: Expected 2 errors in hour $TARGET_HOUR, found $HOUR_ERRORS"
fi
