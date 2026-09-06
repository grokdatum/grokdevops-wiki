#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-incident"
LAB_DIR="/tmp/lab-incident"
PASS=0
FAIL=0
TOTAL=6

echo "=== Incident Response Lab — Grading ==="
echo ""

# --- Objective 1: Payment API pods running ---
echo -n "[1/6] Payment API pods are Running (incident mitigated): "
not_ready=$(kubectl get pods -n "${NAMESPACE}" -l app=payment-api --no-headers 2>/dev/null | grep -v "Running" | wc -l)
running=$(kubectl get pods -n "${NAMESPACE}" -l app=payment-api --no-headers 2>/dev/null | grep "Running" | wc -l)
if [[ ${running} -ge 1 && ${not_ready} -eq 0 ]]; then
    echo "PASS (${running} pods running)"
    ((PASS++))
else
    echo "FAIL (${running} running, ${not_ready} not ready)"
    ((FAIL++))
fi

# --- Objective 2: All pods healthy ---
echo -n "[2/6] All pods in namespace are healthy: "
total_not_ready=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running" | wc -l)
total_running=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep "Running" | wc -l)
if [[ ${total_not_ready} -eq 0 && ${total_running} -ge 4 ]]; then
    echo "PASS (${total_running} pods healthy)"
    ((PASS++))
else
    echo "FAIL (${total_running} running, ${total_not_ready} unhealthy)"
    ((FAIL++))
fi

# --- Objective 3: Secret was fixed (DB_PASSWORD added) ---
echo -n "[3/6] Root cause fixed (DB_PASSWORD in secret): "
db_pass=$(kubectl get secret payment-config -n "${NAMESPACE}" -o jsonpath='{.data.DB_PASSWORD}' 2>/dev/null || echo "")
if [[ -n "${db_pass}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (DB_PASSWORD still missing from payment-config secret)"
    ((FAIL++))
fi

# --- Objective 4: Timeline file ---
echo -n "[4/6] Timeline file exists with entries: "
if [[ -f "${LAB_DIR}/timeline.txt" ]]; then
    lines=$(wc -l < "${LAB_DIR}/timeline.txt")
    if [[ ${lines} -ge 3 ]]; then
        echo "PASS (${lines} lines)"
        ((PASS++))
    else
        echo "FAIL (only ${lines} lines — need at least 3)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/timeline.txt not found)"
    ((FAIL++))
fi

# --- Objective 5: Postmortem file ---
echo -n "[5/6] Postmortem file exists: "
if [[ -f "${LAB_DIR}/postmortem.txt" ]]; then
    pm_size=$(wc -c < "${LAB_DIR}/postmortem.txt")
    if [[ ${pm_size} -ge 200 ]]; then
        echo "PASS (${pm_size} bytes)"
        ((PASS++))
    else
        echo "FAIL (only ${pm_size} bytes — need at least 200)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/postmortem.txt not found)"
    ((FAIL++))
fi

# --- Objective 6: Postmortem mentions root cause ---
echo -n "[6/6] Postmortem identifies root cause: "
if [[ -f "${LAB_DIR}/postmortem.txt" ]]; then
    if grep -qiE "DB_PASSWORD|secret|missing.*password|password.*missing" "${LAB_DIR}/postmortem.txt"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (root cause not mentioned — should reference DB_PASSWORD or missing secret)"
        ((FAIL++))
    fi
else
    echo "FAIL (no postmortem file)"
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
