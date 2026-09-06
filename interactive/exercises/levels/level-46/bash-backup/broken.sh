#!/bin/bash
# Backup script that creates timestamped archives

BACKUP_DIR="/tmp/backups_$$"
mkdir -p "$BACKUP_DIR"

# BUG: Wrong date format - %m is month, %M is minute. Using %M instead of %m
TIMESTAMP=$(date +"%Y-%M-%d_%H:%M:%S" 2>/dev/null || echo "2024-00-15_14:30:00")

# For testing, use a fixed timestamp to demonstrate the bug
TIMESTAMP_BROKEN="2024-30-15_14:30:00"  # 30 is minutes, not month!
TIMESTAMP_CORRECT="2024-01-15_14:30:00"

BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP_BROKEN}.tar.gz"
echo "test" > "$BACKUP_FILE"

# Validate filename format: YYYY-MM-DD
if echo "$BACKUP_FILE" | grep -qE 'backup_[0-9]{4}-[0-1][0-9]-[0-3][0-9]'; then
    echo "SUCCESS: Backup created: $(basename $BACKUP_FILE)"
else
    echo "FAIL: Invalid date in filename: $(basename $BACKUP_FILE)"
fi

rm -rf "$BACKUP_DIR"
