#!/bin/bash
# This script checks if a server has enough memory (in MB)

REQUIRED_MB=512
AVAILABLE_MB=1024

# Fixed: Using -ge for numeric greater-than-or-equal comparison
if [ "$AVAILABLE_MB" -ge "$REQUIRED_MB" ]; then
    echo "SUCCESS: Sufficient memory available (${AVAILABLE_MB}MB >= ${REQUIRED_MB}MB)"
else
    echo "FAIL: Memory check failed"
fi
