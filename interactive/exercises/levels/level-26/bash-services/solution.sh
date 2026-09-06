#!/bin/bash
# This script checks if a service is running and reports status

# Simulate systemctl is-active (returns 0 for active, non-zero for inactive)
check_service() {
    local service="$1"
    # Simulate: nginx is running
    if [ "$service" = "nginx" ]; then
        return 0  # active
    else
        return 1  # inactive
    fi
}

SERVICE="nginx"

# Fixed: Exit code 0 means success/active, so use -eq 0
check_service "$SERVICE"
if [ $? -eq 0 ]; then
    echo "SUCCESS: $SERVICE is running"
else
    echo "FAIL: $SERVICE is not running"
fi
