#!/bin/bash
# This script checks if a server has enough memory (in MB)

REQUIRED_MB=512
AVAILABLE_MB=1024

# BUG: Using string comparison = instead of numeric comparison -ge
# 1024 = 512 is false, so the script wrongly reports insufficient memory
if [ "$AVAILABLE_MB" = "$REQUIRED_MB" ]; then
    echo "SUCCESS: Sufficient memory available (${AVAILABLE_MB}MB >= ${REQUIRED_MB}MB)"
else
    echo "FAIL: Memory check failed"
fi
