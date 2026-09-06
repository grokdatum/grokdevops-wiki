#!/bin/bash
# This script sets up signal handling for graceful shutdown

CLEANED_UP=false

cleanup() {
    CLEANED_UP=true
    echo "Cleaning up temporary files..."
    echo "Shutdown complete"
}

# BUG: Trapping SIGUSR1 instead of SIGTERM for graceful shutdown
trap cleanup USR1

# Simulate receiving SIGTERM (what docker/k8s sends)
# Send ourselves SIGTERM
kill -TERM $$

# Check if cleanup ran
if [ "$CLEANED_UP" = true ]; then
    echo "SUCCESS: Graceful shutdown handled correctly"
else
    echo "FAIL: Signal handler did not run"
fi
