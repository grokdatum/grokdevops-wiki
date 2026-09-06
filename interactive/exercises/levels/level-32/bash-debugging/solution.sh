#!/bin/bash
# This script processes data with debug logging

DEBUG=true

debug_log() {
    if [ "$DEBUG" = true ]; then
        # Fixed: Send debug output to stderr so it doesn't contaminate stdout
        echo "[DEBUG] $1" >&2
    fi
}

process_data() {
    debug_log "Starting data processing"
    echo "processed_result_42"
    debug_log "Processing complete"
}

# Capture the result - debug messages go to stderr, not stdout
RESULT=$(process_data)

# The result should be ONLY "processed_result_42"
if [ "$RESULT" = "processed_result_42" ]; then
    echo "SUCCESS: Clean output captured: $RESULT"
else
    echo "FAIL: Output contaminated with debug messages: $RESULT"
fi
