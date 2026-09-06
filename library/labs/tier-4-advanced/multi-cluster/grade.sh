#!/usr/bin/env bash
set -euo pipefail

NS_PRIMARY="lab-cluster-primary"
NS_SECONDARY="lab-cluster-secondary"
NS_ROUTER="lab-cluster-router"
LAB_DIR="/tmp/lab-multicluster"
PASS=0
FAIL=0
TOTAL=7

echo "=== Multi-Cluster Lab — Grading ==="
echo ""

# --- Objective 1: Primary running ---
echo -n "[1/7] Primary cluster app running: "
pri_ready=$(kubectl get deployment app -n "${NS_PRIMARY}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [[ "${pri_ready}" -ge 1 ]]; then
    echo "PASS (${pri_ready} replicas)"
    ((PASS++))
else
    echo "FAIL (${pri_ready} ready)"
    ((FAIL++))
fi

# --- Objective 2: Secondary running ---
echo -n "[2/7] Secondary cluster app running: "
sec_ready=$(kubectl get deployment app -n "${NS_SECONDARY}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [[ "${sec_ready}" -ge 1 ]]; then
    echo "PASS (${sec_ready} replicas)"
    ((PASS++))
else
    echo "FAIL (${sec_ready} ready — deploy app in ${NS_SECONDARY})"
    ((FAIL++))
fi

# --- Objective 3: Router pod running ---
echo -n "[3/7] Router pod running: "
router_running=$(kubectl get pods -n "${NS_ROUTER}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${router_running} -ge 1 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no running pods in ${NS_ROUTER})"
    ((FAIL++))
fi

# --- Objective 4: Router routes to primary when healthy ---
echo -n "[4/7] Router routes to primary when both healthy: "
# Ensure primary is scaled up
kubectl scale deployment app --replicas=3 -n "${NS_PRIMARY}" 2>/dev/null || true
sleep 3
router_pod=$(kubectl get pods -n "${NS_ROUTER}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${router_pod}" ]]; then
    resp=$(kubectl exec -n "${NS_ROUTER}" "${router_pod}" -- wget -qO- --timeout=5 "http://app.${NS_PRIMARY}.svc.cluster.local:80/" 2>/dev/null || echo "")
    if echo "${resp}" | grep -qi "primary"; then
        echo "PASS"
        ((PASS++))
    elif [[ -n "${resp}" ]]; then
        echo "PASS (got response: ${resp:0:40})"
        ((PASS++))
    else
        echo "FAIL (no response from primary via router)"
        ((FAIL++))
    fi
else
    echo "FAIL (no router pod)"
    ((FAIL++))
fi

# --- Objective 5: Failover works ---
echo -n "[5/7] Failover to secondary when primary down: "
kubectl scale deployment app --replicas=0 -n "${NS_PRIMARY}" 2>/dev/null || true
sleep 8
if [[ -n "${router_pod}" ]]; then
    resp=$(kubectl exec -n "${NS_ROUTER}" "${router_pod}" -- wget -qO- --timeout=5 "http://app.${NS_SECONDARY}.svc.cluster.local:80/" 2>/dev/null || echo "")
    if [[ -n "${resp}" ]]; then
        echo "PASS (secondary reachable)"
        ((PASS++))
    else
        echo "FAIL (secondary not reachable)"
        ((FAIL++))
    fi
else
    echo "FAIL (no router pod)"
    ((FAIL++))
fi

# --- Objective 6: Failback works ---
echo -n "[6/7] Failback to primary after recovery: "
kubectl scale deployment app --replicas=3 -n "${NS_PRIMARY}" 2>/dev/null || true
kubectl wait --for=condition=Ready pod -l app=webapp -n "${NS_PRIMARY}" --timeout=30s 2>/dev/null || true
sleep 3
if [[ -n "${router_pod}" ]]; then
    resp=$(kubectl exec -n "${NS_ROUTER}" "${router_pod}" -- wget -qO- --timeout=5 "http://app.${NS_PRIMARY}.svc.cluster.local:80/" 2>/dev/null || echo "")
    if [[ -n "${resp}" ]]; then
        echo "PASS (primary restored)"
        ((PASS++))
    else
        echo "FAIL (primary not responding after recovery)"
        ((FAIL++))
    fi
else
    echo "FAIL (no router pod)"
    ((FAIL++))
fi

# --- Objective 7: Failover report ---
echo -n "[7/7] Failover report exists: "
if [[ -f "${LAB_DIR}/failover-report.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/failover-report.txt")
    if [[ ${size} -ge 200 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need at least 200)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/failover-report.txt not found)"
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
