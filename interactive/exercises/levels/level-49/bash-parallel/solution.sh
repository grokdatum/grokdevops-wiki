#!/bin/bash
# This script processes multiple servers in parallel

SERVERS="web-01
web-02
web-03
api-01
api-02
api-03"

process_server() {
    local server="$1"
    echo "Processed: $server"
}

export -f process_server

# Fixed: Use -P3 for 3 parallel jobs and -I{} for argument substitution
PROCESSED=$(echo "$SERVERS" | xargs -I{} -P3 bash -c 'process_server "$@"' _ {} 2>&1 | grep -c "Processed:")

if [ "$PROCESSED" -eq 6 ]; then
    echo "SUCCESS: All 6 servers processed with controlled parallelism"
else
    echo "FAIL: Only $PROCESSED servers processed"
fi
