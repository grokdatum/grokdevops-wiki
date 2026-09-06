#!/bin/bash
# This script checks HTTP status of endpoints

check_health() {
    local url="$1"

    # Simulate curl response for testing
    # BUG: Using -L without -s means progress meter output contaminates result
    # Also the wrong option for write-out is used (missing -o /dev/null)
    CURL_OPTS="-L -w %{http_code}"

    # For testing purposes, simulate the response
    if [ "$url" = "https://api.example.com/health" ]; then
        echo "200"
    elif [ "$url" = "http://api.example.com/health" ]; then
        # BUG: Wrong protocol - should use https not http
        echo "301"
    fi
}

URL="http://api.example.com/health"
STATUS=$(check_health "$URL")

if [ "$STATUS" = "200" ]; then
    echo "SUCCESS: Health check passed with HTTP $STATUS"
else
    echo "FAIL: Health check returned HTTP $STATUS (expected 200)"
fi
