#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-incident-sim"
LAB_DIR="/tmp/lab-incident-sim"
PASS=0
FAIL=0
TOTAL=8

echo "=== Incident Simulation Lab — Grading ==="
echo ""

# --- Objective 1: Database pod healthy ---
echo -n "[1/8] Database pod Running (root cause fixed): "
db_phase=$(kubectl get pods -n "${NAMESPACE}" -l app=database -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
db_restarts=$(kubectl get pods -n "${NAMESPACE}" -l app=database -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "99")
if [[ "${db_phase}" == "Running" ]]; then
    echo "PASS (phase=${db_phase})"
    ((PASS++))
else
    echo "FAIL (phase=${db_phase:-not found})"
    ((FAIL++))
fi

# --- Objective 2: Order service healthy ---
echo -n "[2/8] Order service pods Running: "
order_running=$(kubectl get pods -n "${NAMESPACE}" -l app=order-service --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${order_running} -ge 1 ]]; then
    echo "PASS (${order_running} pods)"
    ((PASS++))
else
    echo "FAIL (${order_running} running)"
    ((FAIL++))
fi

# --- Objective 3: Payment gateway healthy ---
echo -n "[3/8] Payment gateway pods Running: "
pg_running=$(kubectl get pods -n "${NAMESPACE}" -l app=payment-gateway --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${pg_running} -ge 1 ]]; then
    echo "PASS (${pg_running} pods)"
    ((PASS++))
else
    echo "FAIL (${pg_running} running)"
    ((FAIL++))
fi

# --- Objective 4: DB resource limits increased (root cause fix) ---
echo -n "[4/8] Database resource limits increased (root cause addressed): "
db_mem=$(kubectl get deployment database -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
mem_num=$(echo "${db_mem}" | sed 's/Mi//;s/Gi/000/' || echo "0")
if [[ "${mem_num}" -ge 32 ]]; then
    echo "PASS (memory limit=${db_mem})"
    ((PASS++))
else
    echo "FAIL (memory limit=${db_mem:-not set} — was 8Mi, needs increase)"
    ((FAIL++))
fi

# --- Objective 5: Timeline ---
echo -n "[5/8] Timeline file exists: "
if [[ -f "${LAB_DIR}/timeline.txt" ]]; then
    lines=$(wc -l < "${LAB_DIR}/timeline.txt")
    if [[ ${lines} -ge 5 ]]; then
        echo "PASS (${lines} lines)"
        ((PASS++))
    else
        echo "FAIL (${lines} lines — need at least 5)"
        ((FAIL++))
    fi
else
    echo "FAIL (not found)"
    ((FAIL++))
fi

# --- Objective 6: Status update ---
echo -n "[6/8] Status update for VP exists: "
if [[ -f "${LAB_DIR}/status-update.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/status-update.txt")
    if [[ ${size} -ge 100 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need at least 100)"
        ((FAIL++))
    fi
else
    echo "FAIL (not found)"
    ((FAIL++))
fi

# --- Objective 7: Postmortem ---
echo -n "[7/8] Postmortem exists: "
if [[ -f "${LAB_DIR}/postmortem.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/postmortem.txt")
    if [[ ${size} -ge 500 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need at least 500)"
        ((FAIL++))
    fi
else
    echo "FAIL (not found)"
    ((FAIL++))
fi

# --- Objective 8: Postmortem has action items ---
echo -n "[8/8] Postmortem includes 3+ action items: "
if [[ -f "${LAB_DIR}/postmortem.txt" ]]; then
    action_count=$(grep -ciE "action item|todo|TODO|\[ \]|improvement|recommendation" "${LAB_DIR}/postmortem.txt" || echo 0)
    # Also count numbered items that look like actions
    numbered=$(grep -cE '^\s*[0-9]+\.' "${LAB_DIR}/postmortem.txt" || echo 0)
    bullet=$(grep -cE '^\s*[-*]' "${LAB_DIR}/postmortem.txt" || echo 0)
    total=$((action_count + numbered + bullet))
    if [[ ${total} -ge 3 ]]; then
        echo "PASS (${total} items found)"
        ((PASS++))
    else
        echo "FAIL (${total} items — need at least 3)"
        ((FAIL++))
    fi
else
    echo "FAIL (no postmortem)"
    ((FAIL++))
fi

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Passed: ${PASS}/${TOTAL}"
echo "Failed: ${FAIL}/${TOTAL}"

if [[ ${PASS} -eq ${TOTAL} ]]; then
    echo "Status: INCIDENT RESOLVED — ALL OBJECTIVES COMPLETE"
    exit 0
else
    echo "Status: INCIDENT ONGOING — OBJECTIVES INCOMPLETE"
    exit 1
fi
