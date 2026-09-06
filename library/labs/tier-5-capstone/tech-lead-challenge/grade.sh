#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-techlead"
LAB_DIR="/tmp/lab-techlead"
PASS=0
FAIL=0
TOTAL=7

echo "=== Tech Lead Challenge Lab — Grading ==="
echo ""

# --- Objective 1: All 5 decision documents completed ---
echo -n "[1/7] All 5 decision documents completed: "
completed=0
for doc in "${LAB_DIR}/decisions/"*.md; do
    if [[ -f "${doc}" ]]; then
        size=$(wc -c < "${doc}")
        # Must be more than the template (about 400 bytes)
        if [[ ${size} -ge 600 ]]; then
            ((completed++))
        fi
    fi
done
if [[ ${completed} -ge 5 ]]; then
    echo "PASS (${completed}/5 documents)"
    ((PASS++))
else
    echo "FAIL (${completed}/5 documents completed — each must be >600 bytes)"
    ((FAIL++))
fi

# --- Objective 2: Decisions have recommendation and reasoning ---
echo -n "[2/7] Decisions include recommendation and reasoning: "
has_decision=0
for doc in "${LAB_DIR}/decisions/"*.md; do
    if [[ -f "${doc}" ]]; then
        if grep -qiE "decision|chose|recommend|selected" "${doc}" && grep -qiE "because|reason|rationale|why" "${doc}"; then
            ((has_decision++))
        fi
    fi
done
if [[ ${has_decision} -ge 4 ]]; then
    echo "PASS (${has_decision}/5 have decision+reasoning)"
    ((PASS++))
else
    echo "FAIL (${has_decision}/5 — need decision and reasoning in each)"
    ((FAIL++))
fi

# --- Objective 3: PoC 1 — Multi-namespace cluster layout ---
echo -n "[3/7] PoC 1: Multi-namespace layout deployed: "
ns_count=0
for ns in lab-team-alpha lab-team-beta lab-team-gamma; do
    kubectl get namespace "${ns}" > /dev/null 2>&1 && ((ns_count++))
done
if [[ ${ns_count} -ge 2 ]]; then
    echo "PASS (${ns_count} team namespaces)"
    ((PASS++))
else
    # Check for pods in lab-techlead with team labels
    team_pods=$(kubectl get pods -n "${NAMESPACE}" -o json 2>/dev/null | grep -c "team" || echo 0)
    if [[ ${team_pods} -ge 2 ]]; then
        echo "PASS (team pods in ${NAMESPACE})"
        ((PASS++))
    else
        echo "FAIL (${ns_count} team namespaces — need at least 2)"
        ((FAIL++))
    fi
fi

# --- Objective 4: PoC 2 — GitOps workflow ---
echo -n "[4/7] PoC 2: GitOps workflow deployed: "
gitops_pods=$(kubectl get pods -n "${NAMESPACE}" -o json 2>/dev/null | grep -ciE "gitops\|argocd\|flux\|sync" || echo 0)
gitops_deploy=$(kubectl get deployments -n "${NAMESPACE}" -o json 2>/dev/null | grep -ciE "gitops\|argocd\|flux\|sync" || echo 0)
if [[ $((gitops_pods + gitops_deploy)) -ge 1 ]]; then
    echo "PASS"
    ((PASS++))
else
    # Check for any ConfigMap or script representing GitOps
    gitops_cm=$(kubectl get configmap -n "${NAMESPACE}" -o json 2>/dev/null | grep -ciE "gitops\|sync\|reconcile" || echo 0)
    if [[ ${gitops_cm} -ge 1 ]]; then
        echo "PASS (GitOps config found)"
        ((PASS++))
    else
        echo "FAIL (no GitOps workload found — deploy with label containing 'gitops')"
        ((FAIL++))
    fi
fi

# --- Objective 5: PoC 3 — Secret management ---
echo -n "[5/7] PoC 3: Secret management solution deployed: "
secret_count=$(kubectl get secrets -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "default-token\|service-account" | wc -l)
secret_pods=$(kubectl get pods -n "${NAMESPACE}" -o json 2>/dev/null | grep -ciE "vault\|sealed\|secret" || echo 0)
if [[ ${secret_count} -ge 1 || ${secret_pods} -ge 1 ]]; then
    echo "PASS (${secret_count} secrets, ${secret_pods} related pods)"
    ((PASS++))
else
    echo "FAIL (no secret management artifacts found)"
    ((FAIL++))
fi

# --- Objective 6: PoCs running ---
echo -n "[6/7] PoC workloads are running in cluster: "
total_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${total_pods} -ge 2 ]]; then
    echo "PASS (${total_pods} running pods)"
    ((PASS++))
else
    echo "FAIL (${total_pods} running — need at least 2)"
    ((FAIL++))
fi

# --- Objective 7: Executive summary ---
echo -n "[7/7] Executive summary exists: "
if [[ -f "${LAB_DIR}/executive-summary.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/executive-summary.txt")
    if [[ ${size} -ge 500 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need 500+)"
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
    echo "Status: TECH LEAD CHALLENGE COMPLETE — WELL DONE"
    exit 0
else
    echo "Status: CHALLENGE INCOMPLETE"
    exit 1
fi
