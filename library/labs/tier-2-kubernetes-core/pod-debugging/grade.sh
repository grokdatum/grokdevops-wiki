#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-pod-debug"
PASS=0
FAIL=0
TOTAL=9

echo "=== Pod Debugging Lab — Grading ==="
echo ""

check_pod_running() {
    local pod_name="$1"
    local label="$2"
    local phase
    phase=$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    local ready
    ready=$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    local restarts
    restarts=$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "-1")

    echo -n "${label}: "
    if [[ "${phase}" == "Running" && "${ready}" == "True" ]]; then
        echo "PASS (Running, Ready, restarts=${restarts})"
        ((PASS++))
    elif [[ "${phase}" == "NotFound" ]]; then
        # Student may have recreated with different name — check by label
        echo "FAIL (pod not found)"
        ((FAIL++))
    else
        echo "FAIL (phase=${phase}, ready=${ready}, restarts=${restarts})"
        ((FAIL++))
    fi
}

# Check each pod
echo -n "[1/9] "
check_pod_running "broken-image" "Image pull fix"

echo -n "[2/9] "
check_pod_running "broken-oom" "OOM fix"

echo -n "[3/9] "
check_pod_running "broken-liveness" "Liveness probe fix"

echo -n "[4/9] "
check_pod_running "broken-readiness" "Readiness probe fix"

echo -n "[5/9] "
check_pod_running "broken-secret" "Secret fix"

echo -n "[6/9] "
check_pod_running "broken-configmap" "ConfigMap fix"

echo -n "[7/9] "
check_pod_running "broken-command" "Command fix"

echo -n "[8/9] "
check_pod_running "broken-pending" "Pending fix"

echo -n "[9/9] "
check_pod_running "broken-security" "Security context fix"

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
