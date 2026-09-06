#!/bin/bash
# This script logs messages at different severity levels

log_message() {
    local level="$1"
    local message="$2"

    # BUG: Using 'user.info' for error messages instead of 'user.err'
    # All messages get logged as info regardless of actual severity
    case "$level" in
        error)   PRIORITY="user.info" ;;   # Should be user.err
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
