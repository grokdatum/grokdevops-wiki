#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-oncall"
LAB_DIR="/tmp/lab-oncall"
PASS=0
FAIL=0
TOTAL=8

echo "=== On-Call Shift Lab — Grading ==="
echo ""

# --- Objective 1: Full stack deployed ---
echo -n "[1/8] All 6 services have deployments: "
dep_count=$(kubectl get deployments -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)
if [[ ${dep_count} -ge 6 ]]; then
    echo "PASS (${dep_count} deployments)"
    ((PASS++))
else
    echo "FAIL (${dep_count}/6 deployments)"
    ((FAIL++))
fi

# --- Objective 2: Alert 1 — user-service fixed ---
echo -n "[2/8] Alert 1: user-service running (ConfigMap created): "
us_running=$(kubectl get pods -n "${NAMESPACE}" -l app=user-service --no-headers 2>/dev/null | grep -c "Running" || echo 0)
cm_exists=$(kubectl get configmap user-service-config -n "${NAMESPACE}" -o name 2>/dev/null || echo "")
if [[ ${us_running} -ge 1 && -n "${cm_exists}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (running=${us_running}, configmap=${cm_exists:-missing})"
    ((FAIL++))
fi

# --- Objective 3: Alert 2 — payment-service memory fixed ---
echo -n "[3/8] Alert 2: payment-service stable (memory limit increased): "
ps_mem=$(kubectl get deployment payment-service -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
ps_running=$(kubectl get pods -n "${NAMESPACE}" -l app=payment-service --no-headers 2>/dev/null | grep -c "Running" || echo 0)
mem_num=$(echo "${ps_mem}" | sed 's/Mi//;s/Gi/000/' || echo "0")
if [[ "${mem_num}" -ge 64 && ${ps_running} -ge 1 ]]; then
    echo "PASS (limit=${ps_mem}, ${ps_running} running)"
    ((PASS++))
else
    echo "FAIL (limit=${ps_mem:-unknown}, ${ps_running} running)"
    ((FAIL++))
fi

# --- Objective 4: Alert 3 — Certificate acknowledged in log ---
echo -n "[4/8] Alert 3: Certificate warning acknowledged in shift log: "
if [[ -f "${LAB_DIR}/shift-log.txt" ]]; then
    if grep -qiE "cert|certificate|tls|expir" "${LAB_DIR}/shift-log.txt"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no certificate mention in shift log)"
        ((FAIL++))
    fi
else
    echo "FAIL (no shift log)"
    ((FAIL++))
fi

# --- Objective 5: Alert 4 — Database connection investigated ---
echo -n "[5/8] Alert 4: Database connection issue documented: "
if [[ -f "${LAB_DIR}/shift-log.txt" ]]; then
    if grep -qiE "database|redis|connection|spike" "${LAB_DIR}/shift-log.txt"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no database/connection mention in shift log)"
        ((FAIL++))
    fi
else
    echo "FAIL (no shift log)"
    ((FAIL++))
fi

# --- Objective 6: Alert 5 — Disk pressure documented ---
echo -n "[6/8] Alert 5: Disk pressure documented: "
if [[ -f "${LAB_DIR}/shift-log.txt" ]]; then
    if grep -qiE "disk|pressure|storage|cleanup" "${LAB_DIR}/shift-log.txt"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no disk/pressure mention in shift log)"
        ((FAIL++))
    fi
else
    echo "FAIL (no shift log)"
    ((FAIL++))
fi

# --- Objective 7: Shift log ---
echo -n "[7/8] Shift log exists with entries: "
if [[ -f "${LAB_DIR}/shift-log.txt" ]]; then
    lines=$(wc -l < "${LAB_DIR}/shift-log.txt")
    if [[ ${lines} -ge 10 ]]; then
        echo "PASS (${lines} lines)"
        ((PASS++))
    else
        echo "FAIL (${lines} lines — need 10+)"
        ((FAIL++))
    fi
else
    echo "FAIL (not found)"
    ((FAIL++))
fi

# --- Objective 8: Handoff notes ---
echo -n "[8/8] Handoff notes exist: "
if [[ -f "${LAB_DIR}/handoff.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/handoff.txt")
    if [[ ${size} -ge 200 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need 200+)"
        ((FAIL++))
    fi
else
    echo "FAIL (not found)"
    ((FAIL++))
fi

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Passed: ${PASS}/${TOTAL}"
echo "Failed: ${FAIL}/${TOTAL}"

if [[ ${PASS} -eq ${TOTAL} ]]; then
    echo "Status: SHIFT COMPLETE — ALL ALERTS HANDLED"
    exit 0
else
    echo "Status: SHIFT INCOMPLETE — REVIEW OPEN ALERTS"
    exit 1
fi
