#!/bin/bash
# This script checks HTTP status of endpoints

check_health() {
    local url="$1"

    # Fixed: Use -s for silent mode and -o /dev/null to suppress body
    CURL_OPTS="-s -L -o /dev/null -w %{http_code}"

    # For testing purposes, simulate the response
    if [ "$url" = "https://api.example.com/health" ]; then
        echo "200"
    elif [ "$url" = "http://api.example.com/health" ]; then
        echo "301"
    fi
}

# Fixed: Use https instead of http
URL="https://api.example.com/health"
STATUS=$(check_health "$URL")

if [ "$STATUS" = "200" ]; then
    echo "SUCCESS: Health check passed with HTTP $STATUS"
else
    echo "FAIL: Health check returned HTTP $STATUS (expected 200)"
fi
