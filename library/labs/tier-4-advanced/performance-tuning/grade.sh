#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-perf"
LAB_DIR="/tmp/lab-perf"
PASS=0
FAIL=0
TOTAL=7

echo "=== Performance Tuning Lab — Grading ==="
echo ""

# --- Objective 1: CPU limits increased ---
echo -n "[1/7] CPU limits reasonable (>= 100m): "
cpu_limit=$(kubectl get deployment webapp -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "0m")
cpu_num=$(echo "${cpu_limit}" | sed 's/m//')
if [[ "${cpu_num}" -ge 100 ]]; then
    echo "PASS (${cpu_limit})"
    ((PASS++))
else
    echo "FAIL (${cpu_limit} — need at least 100m)"
    ((FAIL++))
fi

# --- Objective 2: Memory limits reasonable ---
echo -n "[2/7] Memory limits have headroom (>= 128Mi): "
mem_limit=$(kubectl get deployment webapp -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "0Mi")
mem_num=$(echo "${mem_limit}" | sed 's/Mi//')
if [[ "${mem_num}" -ge 128 ]]; then
    echo "PASS (${mem_limit})"
    ((PASS++))
else
    echo "FAIL (${mem_limit} — need at least 128Mi)"
    ((FAIL++))
fi

# --- Objective 3: HPA exists ---
echo -n "[3/7] HorizontalPodAutoscaler configured: "
hpa_name=$(kubectl get hpa -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${hpa_name}" ]]; then
    hpa_min=$(kubectl get hpa "${hpa_name}" -n "${NAMESPACE}" -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo "0")
    hpa_max=$(kubectl get hpa "${hpa_name}" -n "${NAMESPACE}" -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || echo "0")
    echo "PASS (min=${hpa_min}, max=${hpa_max})"
    ((PASS++))
else
    echo "FAIL (no HPA found)"
    ((FAIL++))
fi

# --- Objective 4: PodDisruptionBudget exists ---
echo -n "[4/7] PodDisruptionBudget configured: "
pdb_name=$(kubectl get pdb -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${pdb_name}" ]]; then
    echo "PASS (${pdb_name})"
    ((PASS++))
else
    echo "FAIL (no PDB found)"
    ((FAIL++))
fi

# --- Objective 5: Liveness probe tuned ---
echo -n "[5/7] Liveness probe tuned (period >= 10s, threshold >= 3): "
probe_period=$(kubectl get deployment webapp -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.periodSeconds}' 2>/dev/null || echo "0")
probe_threshold=$(kubectl get deployment webapp -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.failureThreshold}' 2>/dev/null || echo "0")
if [[ "${probe_period}" -ge 10 && "${probe_threshold}" -ge 3 ]]; then
    echo "PASS (period=${probe_period}s, threshold=${probe_threshold})"
    ((PASS++))
else
    echo "FAIL (period=${probe_period}s, threshold=${probe_threshold})"
    ((FAIL++))
fi

# --- Objective 6: Pods healthy (not crash-looping) ---
echo -n "[6/7] All pods Running and not crash-looping: "
crashloop=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "CrashLoopBackOff" || echo 0)
running=$(kubectl get pods -n "${NAMESPACE}" -l app=webapp --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${crashloop} -eq 0 && ${running} -ge 1 ]]; then
    echo "PASS (${running} running, 0 crash-looping)"
    ((PASS++))
else
    echo "FAIL (${running} running, ${crashloop} crash-looping)"
    ((FAIL++))
fi

# --- Objective 7: Tuning report ---
echo -n "[7/7] Tuning report exists: "
if [[ -f "${LAB_DIR}/tuning-report.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/tuning-report.txt")
    if [[ ${size} -ge 200 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need at least 200)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/tuning-report.txt not found)"
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
