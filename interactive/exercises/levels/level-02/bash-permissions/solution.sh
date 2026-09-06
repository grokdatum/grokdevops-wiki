#!/bin/bash
# This script creates a helper script and makes it executable

HELPER="/tmp/k8s_helper_$$.sh"
echo '#!/bin/bash' > "$HELPER"
echo 'echo "Helper script running"' >> "$HELPER"

# Fixed: 755 gives owner rwx, group rx, others rx
chmod 755 "$HELPER"

# Test if the helper is executable
if [ -x "$HELPER" ]; then
    echo "SUCCESS: Helper script is executable"
    bash "$HELPER"
else
    echo "FAIL: Helper script is not executable"
fi

rm -f "$HELPER"
