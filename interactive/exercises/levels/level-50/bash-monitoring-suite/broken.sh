#!/bin/bash
# Comprehensive monitoring suite - FINAL CHALLENGE
# This script monitors multiple system metrics and generates a report

REPORT=""
CHECKS_PASSED=0
TOTAL_CHECKS=3

# --- Check 1: Disk Usage ---
check_disk() {
    local threshold=80
    # Simulated df output
    local df_output="Filesystem     1K-blocks    Used Available Use% Mounted on
/dev/sda1       50000000 30000000  20000000  60% /"

    # BUG 1: Wrong awk field ($4 instead of $5 for Use%)
    local usage=$(echo "$df_output" | tail -1 | awk '{print $4}' | tr -d '%')

    if [ "$usage" -lt "$threshold" ] 2>/dev/null; then
        echo "DISK:OK:${usage}%"
        return 0
    else
        echo "DISK:CRITICAL:${usage}%"
        return 1
    fi
}

# --- Check 2: Memory Usage ---
check_memory() {
    # Simulated memory info
    local total=8192
    local used=3072

    # BUG 2: Integer division wrong - missing proper calculation
    # Should calculate percentage: (used * 100) / total
    local pct=$(( total / used ))

    if [ "$pct" -lt 80 ]; then
        echo "MEMORY:OK:${pct}%"
        return 0
    else
        echo "MEMORY:CRITICAL:${pct}%"
        return 1
    fi
}

# --- Check 3: Service Status ---
check_services() {
    local services="nginx:running redis:running postgres:stopped"
    local all_running=true

    for svc in $services; do
        local name=$(echo "$svc" | cut -d: -f1)
        local status=$(echo "$svc" | cut -d: -f2)

        # BUG 3: Comparison operator wrong (using = instead of !=)
        if [ "$status" = "stopped" ]; then
            all_running=false
        fi
    done

    if [ "$all_running" = true ]; then
        echo "SERVICES:OK:all running"
        return 0
    else
        echo "SERVICES:WARNING:some stopped"
        return 1
    fi
}

# Run all checks
DISK_RESULT=$(check_disk)
DISK_STATUS=$?
if [ $DISK_STATUS -eq 0 ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

MEMORY_RESULT=$(check_memory)
MEMORY_STATUS=$?
if [ $MEMORY_STATUS -eq 0 ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

SERVICE_RESULT=$(check_services)
SERVICE_STATUS=$?
if [ $SERVICE_STATUS -eq 0 ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

echo "=== Monitoring Report ==="
echo "$DISK_RESULT"
echo "$MEMORY_RESULT"
echo "$SERVICE_RESULT"
echo "========================="
echo "Checks passed: $CHECKS_PASSED/$TOTAL_CHECKS"

if [ "$CHECKS_PASSED" -eq 2 ]; then
    echo "SUCCESS: Monitoring suite operational ($CHECKS_PASSED/$TOTAL_CHECKS checks healthy)"
else
    echo "FAIL: Expected 2 passing checks (disk + memory), got $CHECKS_PASSED"
fi
