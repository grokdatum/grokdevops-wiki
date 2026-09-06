#!/bin/bash
# This script creates a helper script and makes it executable

HELPER="/tmp/k8s_helper_$$.sh"
echo '#!/bin/bash' > "$HELPER"
echo 'echo "Helper script running"' >> "$HELPER"

# BUG: Wrong chmod mode - 644 is read/write, not executable
chmod 644 "$HELPER"

# Test if the helper is executable
if [ -x "$HELPER" ]; then
    echo "SUCCESS: Helper script is executable"
    bash "$HELPER"
else
    echo "FAIL: Helper script is not executable"
fi

rm -f "$HELPER"
