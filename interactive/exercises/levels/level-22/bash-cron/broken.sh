#!/bin/bash
# This script generates a cron entry for a daily backup at 2:30 AM

BACKUP_CMD="/usr/local/bin/backup.sh"

# BUG: Cron fields are minute hour day month weekday
# This says "hour 30, minute 2" which is wrong (fields swapped)
CRON_EXPR="2 30 * * *"

echo "Cron entry: $CRON_EXPR $BACKUP_CMD"

# Validate the cron expression
MINUTE=$(echo "$CRON_EXPR" | awk '{print $1}')
HOUR=$(echo "$CRON_EXPR" | awk '{print $2}')

if [ "$MINUTE" = "30" ] && [ "$HOUR" = "2" ]; then
    echo "SUCCESS: Backup scheduled for 2:30 AM daily"
else
    echo "FAIL: Cron expression is wrong (minute=$MINUTE, hour=$HOUR)"
fi
