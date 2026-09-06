#!/bin/bash
# This script generates a cron entry for a daily backup at 2:30 AM

BACKUP_CMD="/usr/local/bin/backup.sh"

# Fixed: Correct order is minute(30) hour(2) day(*) month(*) weekday(*)
CRON_EXPR="30 2 * * *"

echo "Cron entry: $CRON_EXPR $BACKUP_CMD"

# Validate the cron expression
MINUTE=$(echo "$CRON_EXPR" | awk '{print $1}')
HOUR=$(echo "$CRON_EXPR" | awk '{print $2}')

if [ "$MINUTE" = "30" ] && [ "$HOUR" = "2" ]; then
    echo "SUCCESS: Backup scheduled for 2:30 AM daily"
else
    echo "FAIL: Cron expression is wrong (minute=$MINUTE, hour=$HOUR)"
fi
