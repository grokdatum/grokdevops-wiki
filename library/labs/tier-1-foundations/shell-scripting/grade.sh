#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-shell"
PASS=0
FAIL=0
TOTAL=7

echo "=== Shell Scripting Lab — Grading ==="
echo ""

MONITOR="${LAB_ROOT}/monitor.sh"

if [[ ! -f "${MONITOR}" ]]; then
    echo "FATAL: ${MONITOR} not found"
    exit 1
fi

if [[ ! -x "${MONITOR}" ]]; then
    echo "FATAL: ${MONITOR} is not executable"
    exit 1
fi

# --- Reset services to known state for grading ---
# 3 healthy, 2 down
echo "ok" > "${LAB_ROOT}/services/web-server/health"
echo "ok" > "${LAB_ROOT}/services/api-gateway/health"
echo "ok" > "${LAB_ROOT}/services/postgresql/health"
echo "connection refused" > "${LAB_ROOT}/services/redis-cache/health"
rm -f "${LAB_ROOT}/services/rabbitmq/health"

# Clear previous logs/alerts
rm -rf "${LAB_ROOT}/logs" "${LAB_ROOT}/alerts"

# --- Run the monitor script ---
echo "Running monitor.sh..."
monitor_exit=0
bash "${MONITOR}" 2>/dev/null || monitor_exit=$?

# --- Objective 1: Script checks services ---
echo -n "[1/7] Script checks all 5 services: "
if [[ -f "${LAB_ROOT}/logs/monitor.log" ]]; then
    checked=$(grep -cE 'web-server|api-gateway|redis-cache|postgresql|rabbitmq' "${LAB_ROOT}/logs/monitor.log" || echo 0)
    if [[ ${checked} -ge 5 ]]; then
        echo "PASS (${checked} service entries in log)"
        ((PASS++))
    else
        echo "FAIL (only ${checked} service entries — need at least 5)"
        ((FAIL++))
    fi
else
    echo "FAIL (no log file created)"
    ((FAIL++))
fi

# --- Objective 2: Log has timestamps ---
echo -n "[2/7] Log entries have timestamps: "
if [[ -f "${LAB_ROOT}/logs/monitor.log" ]]; then
    ts_count=$(grep -cE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ]?[0-9]{2}:[0-9]{2}' "${LAB_ROOT}/logs/monitor.log" || echo 0)
    if [[ ${ts_count} -ge 1 ]]; then
        echo "PASS (${ts_count} timestamped lines)"
        ((PASS++))
    else
        echo "FAIL (no timestamps found)"
        ((FAIL++))
    fi
else
    echo "FAIL (no log file)"
    ((FAIL++))
fi

# --- Objective 3: Alert file lists down services ---
echo -n "[3/7] Alert file lists down services: "
if [[ -f "${LAB_ROOT}/alerts/active.txt" ]]; then
    has_redis=$(grep -c "redis-cache" "${LAB_ROOT}/alerts/active.txt" || echo 0)
    has_rabbit=$(grep -c "rabbitmq" "${LAB_ROOT}/alerts/active.txt" || echo 0)
    if [[ ${has_redis} -gt 0 && ${has_rabbit} -gt 0 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (missing down services in alerts — redis:${has_redis} rabbit:${has_rabbit})"
        ((FAIL++))
    fi
else
    echo "FAIL (no alert file created)"
    ((FAIL++))
fi

# --- Objective 4: Alerts clear on recovery ---
echo -n "[4/7] Alerts clear when service recovers: "
# Fix the broken services
echo "ok" > "${LAB_ROOT}/services/redis-cache/health"
echo "ok" > "${LAB_ROOT}/services/rabbitmq/health"
# Run again
bash "${MONITOR}" 2>/dev/null || true
if [[ -f "${LAB_ROOT}/alerts/active.txt" ]]; then
    remaining=$(wc -l < "${LAB_ROOT}/alerts/active.txt" | tr -d ' ')
    # Allow empty file or file with only whitespace
    content=$(cat "${LAB_ROOT}/alerts/active.txt" | tr -d '[:space:]')
    if [[ -z "${content}" || "${remaining}" -eq 0 ]]; then
        echo "PASS (alerts cleared)"
        ((PASS++))
    else
        echo "FAIL (${remaining} alerts remain after recovery)"
        ((FAIL++))
    fi
else
    echo "PASS (alert file removed on recovery)"
    ((PASS++))
fi

# --- Objective 5: Exit code 0 when all healthy ---
echo -n "[5/7] Exit 0 when all services healthy: "
all_exit=0
bash "${MONITOR}" 2>/dev/null || all_exit=$?
if [[ ${all_exit} -eq 0 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (exit code ${all_exit} — expected 0)"
    ((FAIL++))
fi

# --- Objective 6: Exit code 1 when service down ---
echo -n "[6/7] Exit 1 when service is down: "
echo "error" > "${LAB_ROOT}/services/redis-cache/health"
down_exit=0
bash "${MONITOR}" 2>/dev/null || down_exit=$?
echo "ok" > "${LAB_ROOT}/services/redis-cache/health"  # restore
if [[ ${down_exit} -eq 1 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (exit code ${down_exit} — expected 1)"
    ((FAIL++))
fi

# --- Objective 7: Creates directories if missing ---
echo -n "[7/7] Creates directories if missing: "
rm -rf "${LAB_ROOT}/logs" "${LAB_ROOT}/alerts"
bash "${MONITOR}" 2>/dev/null || true
if [[ -d "${LAB_ROOT}/logs" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (did not create logs directory)"
    ((FAIL++))
fi

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Passed: ${PASS}/${TOTAL}"
echo "Failed: ${FAIL}/${TOTAL}"

if [[ ${PASS} -eq ${TOTAL} ]]; then
    echo "Status: ALL OBJECTIVES COMPLETE"
    exit 0
else
    echo "Status: INCOMPLETE — review failed objectives above"
    exit 1
fi
