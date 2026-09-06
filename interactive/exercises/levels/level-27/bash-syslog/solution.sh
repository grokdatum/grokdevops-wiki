#!/bin/bash
# This script logs messages at different severity levels

log_message() {
    local level="$1"
    local message="$2"

    # Fixed: Use correct syslog priority for errors
    case "$level" in
        error)   PRIORITY="user.err" ;;
        warning) PRIORITY="user.warning" ;;
        info)    PRIORITY="user.info" ;;
    esac

    echo "$PRIORITY: $message"
}

log_message "error" "Database connection failed"
log_message "warning" "High memory usage detected"
log_message "info" "Service started"

# Verify the error was logged correctly
OUTPUT=$(log_message "error" "test")
if echo "$OUTPUT" | grep -q "user.err"; then
    echo "SUCCESS: Error messages use correct priority level"
else
    echo "FAIL: Error messages using wrong priority level"
fi
