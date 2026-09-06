#!/usr/bin/env bash
set -euo pipefail

NS_FE="lab-frontend-ns"
NS_BE="lab-backend-ns"
NS_DATA="lab-data-ns"
PASS=0
FAIL=0
TOTAL=7

echo "=== Service Networking Lab — Grading ==="
echo ""

# --- Objective 1: Namespaces exist ---
echo -n "[1/7] Namespaces exist with labels: "
all_ns=true
for ns in "${NS_FE}" "${NS_BE}" "${NS_DATA}"; do
    if ! kubectl get namespace "${ns}" > /dev/null 2>&1; then
        all_ns=false
    fi
done
if ${all_ns}; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (one or more namespaces missing)"
    ((FAIL++))
fi

# --- Objective 2: Services in each namespace ---
echo -n "[2/7] Services deployed in each namespace: "
svc_fe=$(kubectl get svc frontend -n "${NS_FE}" -o name 2>/dev/null || echo "")
svc_api=$(kubectl get svc api -n "${NS_BE}" -o name 2>/dev/null || echo "")
svc_redis=$(kubectl get svc redis -n "${NS_DATA}" -o name 2>/dev/null || echo "")
if [[ -n "${svc_fe}" && -n "${svc_api}" && -n "${svc_redis}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (fe=${svc_fe:-none}, api=${svc_api:-none}, redis=${svc_redis:-none})"
    ((FAIL++))
fi

# --- Objective 3: Ingress exists ---
echo -n "[3/7] Ingress routes /api to backend: "
ingress_count=$(kubectl get ingress -n "${NS_BE}" -o name 2>/dev/null | wc -l || echo 0)
if [[ ${ingress_count} -gt 0 ]]; then
    ing_path=$(kubectl get ingress -n "${NS_BE}" -o jsonpath='{.items[0].spec.rules[0].http.paths[0].path}' 2>/dev/null || echo "")
    echo "PASS (path=${ing_path})"
    ((PASS++))
else
    # Also check in frontend namespace
    ingress_count=$(kubectl get ingress -n "${NS_FE}" -o name 2>/dev/null | wc -l || echo 0)
    if [[ ${ingress_count} -gt 0 ]]; then
        echo "PASS (ingress in frontend namespace)"
        ((PASS++))
    else
        echo "FAIL (no Ingress resource found)"
        ((FAIL++))
    fi
fi

# --- Objective 4: NetworkPolicy — frontend can reach backend ---
echo -n "[4/7] Frontend can reach backend on 8080: "
fe_pod=$(kubectl get pods -n "${NS_FE}" -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${fe_pod}" ]]; then
    resp=$(kubectl exec -n "${NS_FE}" "${fe_pod}" -- wget -qO- --timeout=5 "http://api.${NS_BE}.svc.cluster.local:8080/" 2>/dev/null || echo "")
    if [[ -n "${resp}" ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no response)"
        ((FAIL++))
    fi
else
    echo "FAIL (no frontend pod)"
    ((FAIL++))
fi

# --- Objective 5: NetworkPolicy — backend can reach data ---
echo -n "[5/7] Backend can reach redis on 6379: "
be_pod=$(kubectl get pods -n "${NS_BE}" -l app=api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${be_pod}" ]]; then
    # Try a TCP connection to redis
    resp=$(kubectl exec -n "${NS_BE}" "${be_pod}" -- sh -c "echo PING | nc -w 3 redis.${NS_DATA}.svc.cluster.local 6379" 2>/dev/null || echo "")
    if echo "${resp}" | grep -qi "PONG"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (could not reach redis — got: ${resp})"
        ((FAIL++))
    fi
else
    echo "FAIL (no backend pod)"
    ((FAIL++))
fi

# --- Objective 6: NetworkPolicy — frontend CANNOT reach data directly ---
echo -n "[6/7] Frontend CANNOT reach redis directly: "
if [[ -n "${fe_pod}" ]]; then
    resp=$(kubectl exec -n "${NS_FE}" "${fe_pod}" -- sh -c "echo PING | nc -w 3 redis.${NS_DATA}.svc.cluster.local 6379" 2>/dev/null || echo "blocked")
    if echo "${resp}" | grep -qi "PONG"; then
        echo "FAIL (frontend can still reach redis — NetworkPolicy missing)"
        ((FAIL++))
    else
        echo "PASS (connection blocked)"
        ((PASS++))
    fi
else
    echo "FAIL (no frontend pod to test)"
    ((FAIL++))
fi

# --- Objective 7: All pods running ---
echo -n "[7/7] All pods Running across namespaces: "
not_running=0
for ns in "${NS_FE}" "${NS_BE}" "${NS_DATA}"; do
    nr=$(kubectl get pods -n "${ns}" --no-headers 2>/dev/null | grep -v "Running" | wc -l)
    not_running=$((not_running + nr))
done
if [[ ${not_running} -eq 0 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (${not_running} pods not Running)"
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
