#!/bin/bash
# Health check script for microservices

check_service() {
    local name="$1"
    local url="$2"

    # Simulate HTTP check (parse protocol and port from URL)
    local proto=$(echo "$url" | sed 's|://.*||')
    local port=$(echo "$url" | sed 's|.*:||' | sed 's|/.*||')

    # Simulate: service runs on https:8443
    if [ "$proto" = "https" ] && [ "$port" = "8443" ]; then
        echo "UP"
    else
        echo "DOWN"
    fi
}

# BUG: Wrong protocol (http instead of https) and wrong port (80 instead of 8443)
API_STATUS=$(check_service "api" "http://api.local:80/health")

if [ "$API_STATUS" = "UP" ]; then
    echo "SUCCESS: API health check passed (status: $API_STATUS)"
else
    echo "FAIL: API health check failed (status: $API_STATUS)"
fi
