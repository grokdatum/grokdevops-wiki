#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-rbac"
PASS=0
FAIL=0
TOTAL=7

echo "=== RBAC & Security Lab — Grading ==="
echo ""

check_can_i() {
    local sa="$1" verb="$2" resource="$3" ns="$4"
    kubectl auth can-i "${verb}" "${resource}" \
        --as="system:serviceaccount:${NAMESPACE}:${sa}" \
        -n "${ns}" 2>/dev/null || echo "no"
}

# --- Objective 1: Namespace exists ---
echo -n "[1/7] Namespace ${NAMESPACE} exists: "
if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL"
    ((FAIL++))
fi

# --- Objective 2: dev-sa has Role and RoleBinding ---
echo -n "[2/7] dev-sa has CRUD on pods/deployments/services in ${NAMESPACE}: "
can_create=$(check_can_i dev-sa create deployments "${NAMESPACE}")
can_delete=$(check_can_i dev-sa delete pods "${NAMESPACE}")
can_list=$(check_can_i dev-sa list services "${NAMESPACE}")
if [[ "${can_create}" == "yes" && "${can_delete}" == "yes" && "${can_list}" == "yes" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (create=${can_create}, delete=${can_delete}, list=${can_list})"
    ((FAIL++))
fi

# --- Objective 3: ops-sa has cluster-wide read + deployment CRUD ---
echo -n "[3/7] ops-sa has cluster-wide read + deployment management: "
ops_list=$(check_can_i ops-sa list pods "kube-system")
ops_deploy=$(check_can_i ops-sa create deployments "${NAMESPACE}")
if [[ "${ops_list}" == "yes" && "${ops_deploy}" == "yes" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (list-kube-system=${ops_list}, create-deploy=${ops_deploy})"
    ((FAIL++))
fi

# --- Objective 4: auditor-sa has read-only everywhere ---
echo -n "[4/7] auditor-sa has read-only access to all resources: "
aud_list=$(check_can_i auditor-sa list pods "kube-system")
aud_get=$(check_can_i auditor-sa get deployments "${NAMESPACE}")
if [[ "${aud_list}" == "yes" && "${aud_get}" == "yes" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (list=${aud_list}, get=${aud_get})"
    ((FAIL++))
fi

# --- Objective 5: dev-sa CAN create in lab-rbac ---
echo -n "[5/7] dev-sa CAN create deployment in ${NAMESPACE}: "
can=$(check_can_i dev-sa create deployments "${NAMESPACE}")
if [[ "${can}" == "yes" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL"
    ((FAIL++))
fi

# --- Objective 6: dev-sa CANNOT list in kube-system ---
echo -n "[6/7] dev-sa CANNOT list pods in kube-system: "
can=$(check_can_i dev-sa list pods "kube-system")
if [[ "${can}" == "no" ]]; then
    echo "PASS (correctly denied)"
    ((PASS++))
else
    echo "FAIL (should be denied but got ${can})"
    ((FAIL++))
fi

# --- Objective 7: auditor-sa CANNOT delete ---
echo -n "[7/7] auditor-sa CANNOT delete pods: "
can=$(check_can_i auditor-sa delete pods "${NAMESPACE}")
if [[ "${can}" == "no" ]]; then
    echo "PASS (correctly denied)"
    ((PASS++))
else
    echo "FAIL (should be denied but got ${can})"
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
