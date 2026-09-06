#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-chaos"
LAB_DIR="/tmp/lab-chaos"
PASS=0
FAIL=0
TOTAL=7

echo "=== Chaos Engineering Lab — Grading ==="
echo ""

# --- Objective 1: App stack still running (survived chaos) ---
echo -n "[1/7] App stack survived chaos (all deployments healthy): "
fe_ready=$(kubectl get deployment frontend -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
api_ready=$(kubectl get deployment api -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
db_ready=$(kubectl get deployment database -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [[ "${fe_ready}" -ge 1 && "${api_ready}" -ge 1 && "${db_ready}" -ge 1 ]]; then
    echo "PASS (fe=${fe_ready}, api=${api_ready}, db=${db_ready})"
    ((PASS++))
else
    echo "FAIL (fe=${fe_ready}, api=${api_ready}, db=${db_ready})"
    ((FAIL++))
fi

# --- Objective 2: Pod was killed and recreated (restart count > 0 or events show delete) ---
echo -n "[2/7] Evidence of pod kill experiment: "
api_restarts=$(kubectl get pods -n "${NAMESPACE}" -l app=api -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
api_events=$(kubectl get events -n "${NAMESPACE}" --field-selector reason=Killing -o name 2>/dev/null | wc -l)
total_restarts=0
for r in ${api_restarts}; do total_restarts=$((total_restarts + r)); done
if [[ ${total_restarts} -gt 0 || ${api_events} -gt 0 ]]; then
    echo "PASS (restarts=${total_restarts}, kill events=${api_events})"
    ((PASS++))
else
    echo "FAIL (no evidence of pod deletion/restart)"
    ((FAIL++))
fi

# --- Objective 3: Resilience report exists ---
echo -n "[3/7] Resilience report file exists: "
REPORT="${LAB_DIR}/resilience-report.txt"
if [[ -f "${REPORT}" ]]; then
    report_size=$(wc -c < "${REPORT}")
    if [[ ${report_size} -ge 500 ]]; then
        echo "PASS (${report_size} bytes)"
        ((PASS++))
    else
        echo "FAIL (only ${report_size} bytes — need at least 500)"
        ((FAIL++))
    fi
else
    echo "FAIL (${REPORT} not found)"
    ((FAIL++))
fi

# --- Objective 4: Report mentions all 5 experiments ---
echo -n "[4/7] Report covers 5 experiment types: "
if [[ -f "${REPORT}" ]]; then
    exp_count=0
    grep -qiE "pod.*kill|kill.*pod|delete.*pod" "${REPORT}" && ((exp_count++)) || true
    grep -qiE "cpu.*stress|stress.*cpu|resource" "${REPORT}" && ((exp_count++)) || true
    grep -qiE "latency|network.*delay|delay" "${REPORT}" && ((exp_count++)) || true
    grep -qiE "storage|disk|ephemeral" "${REPORT}" && ((exp_count++)) || true
    grep -qiE "dns|name.*resolution" "${REPORT}" && ((exp_count++)) || true
    if [[ ${exp_count} -ge 4 ]]; then
        echo "PASS (${exp_count}/5 experiment types mentioned)"
        ((PASS++))
    else
        echo "FAIL (only ${exp_count}/5 experiment types mentioned)"
        ((FAIL++))
    fi
else
    echo "FAIL (no report)"
    ((FAIL++))
fi

# --- Objective 5: Report has hypothesis/observation structure ---
echo -n "[5/7] Report follows experiment structure (hypothesis/observation): "
if [[ -f "${REPORT}" ]]; then
    has_structure=0
    grep -qiE "hypothes|expect" "${REPORT}" && ((has_structure++)) || true
    grep -qiE "observ|result|finding" "${REPORT}" && ((has_structure++)) || true
    grep -qiE "recommend|action|improv" "${REPORT}" && ((has_structure++)) || true
    if [[ ${has_structure} -ge 2 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (missing hypothesis/observation/recommendation structure)"
        ((FAIL++))
    fi
else
    echo "FAIL (no report)"
    ((FAIL++))
fi

# --- Objective 6: Frontend service still responding ---
echo -n "[6/7] Frontend service is accessible: "
fe_pod=$(kubectl get pods -n "${NAMESPACE}" -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${fe_pod}" ]]; then
    response=$(kubectl exec -n "${NAMESPACE}" "${fe_pod}" -- wget -qO- --timeout=5 http://localhost/ 2>/dev/null || echo "")
    if [[ -n "${response}" ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no response from frontend)"
        ((FAIL++))
    fi
else
    echo "FAIL (no frontend pod)"
    ((FAIL++))
fi

# --- Objective 7: API service still responding ---
echo -n "[7/7] API service is accessible: "
api_pod=$(kubectl get pods -n "${NAMESPACE}" -l app=api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${api_pod}" ]]; then
    response=$(kubectl exec -n "${NAMESPACE}" "${fe_pod}" -- wget -qO- --timeout=5 http://api.${NAMESPACE}.svc.cluster.local:8080/ 2>/dev/null || echo "")
    if [[ -n "${response}" ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no response from API)"
        ((FAIL++))
    fi
else
    echo "FAIL (no API pod)"
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
