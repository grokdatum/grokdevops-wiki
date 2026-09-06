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

# BUG: xargs without -I{} or proper bash -c invocation
# cannot find "process_server" as an external command
PROCESSED=$(echo "$SERVERS" | xargs -P3 process_server 2>&1 | grep -c "Processed:")

if [ "$PROCESSED" -eq 6 ]; then
    echo "SUCCESS: All 6 servers processed with controlled parallelism"
else
    echo "FAIL: Only $PROCESSED servers processed"
fi
