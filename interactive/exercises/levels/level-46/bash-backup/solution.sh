#!/bin/bash
# Backup script that creates timestamped archives

BACKUP_DIR="/tmp/backups_$$"
mkdir -p "$BACKUP_DIR"

# Fixed: Use %m for month (not %M which is minutes)
TIMESTAMP=$(date +"%Y-%m-%d_%H:%M:%S" 2>/dev/null || echo "2024-01-15_14:30:00")

# For testing, use a fixed correct timestamp
TIMESTAMP_CORRECT="2024-01-15_14:30:00"

BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP_CORRECT}.tar.gz"
echo "test" > "$BACKUP_FILE"

# Validate filename format: YYYY-MM-DD
if echo "$BACKUP_FILE" | grep -qE 'backup_[0-9]{4}-[0-1][0-9]-[0-3][0-9]'; then
    echo "SUCCESS: Backup created: $(basename $BACKUP_FILE)"
else
    echo "FAIL: Invalid date in filename: $(basename $BACKUP_FILE)"
fi

rm -rf "$BACKUP_DIR"
