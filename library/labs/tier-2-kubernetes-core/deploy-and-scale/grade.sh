#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-deploy"
PASS=0
FAIL=0
TOTAL=7

echo "=== Deploy & Scale Lab — Grading ==="
echo ""

# --- Objective 1: Frontend 3 replicas with resources ---
echo -n "[1/7] Frontend: 3 replicas with resource limits: "
fe_replicas=$(kubectl get deployment frontend -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
fe_limits=$(kubectl get deployment frontend -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
if [[ "${fe_replicas}" == "3" && -n "${fe_limits}" ]]; then
    echo "PASS (replicas=${fe_replicas}, mem-limit=${fe_limits})"
    ((PASS++))
else
    echo "FAIL (replicas=${fe_replicas}, mem-limit=${fe_limits:-none})"
    ((FAIL++))
fi

# --- Objective 2: API 2 replicas with probe ---
echo -n "[2/7] API: 2 replicas with readiness probe: "
api_replicas=$(kubectl get deployment api -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
api_probe=$(kubectl get deployment api -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null || echo "")
api_limits=$(kubectl get deployment api -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
if [[ "${api_replicas}" == "2" && -n "${api_probe}" && -n "${api_limits}" ]]; then
    echo "PASS (replicas=${api_replicas}, probe=${api_probe})"
    ((PASS++))
else
    echo "FAIL (replicas=${api_replicas}, probe=${api_probe:-none}, limits=${api_limits:-none})"
    ((FAIL++))
fi

# --- Objective 3: PostgreSQL deployment with PVC ---
echo -n "[3/7] PostgreSQL deployed with PVC: "
db_exists=$(kubectl get deployment -n "${NAMESPACE}" -l app=postgresql -o name 2>/dev/null || kubectl get deployment -n "${NAMESPACE}" -l app=postgres -o name 2>/dev/null || kubectl get deployment -n "${NAMESPACE}" -l app=db -o name 2>/dev/null || echo "")
pvc_exists=$(kubectl get pvc -n "${NAMESPACE}" -o name 2>/dev/null | head -1)
if [[ -n "${db_exists}" && -n "${pvc_exists}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (deployment=${db_exists:-none}, pvc=${pvc_exists:-none})"
    ((FAIL++))
fi

# --- Objective 4: Services for all tiers ---
echo -n "[4/7] ClusterIP services for all tiers: "
svc_fe=$(kubectl get svc frontend -n "${NAMESPACE}" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
svc_api=$(kubectl get svc api -n "${NAMESPACE}" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
svc_db=$(kubectl get svc -n "${NAMESPACE}" -l app=postgresql -o jsonpath='{.items[0].spec.type}' 2>/dev/null || kubectl get svc -n "${NAMESPACE}" -l app=postgres -o jsonpath='{.items[0].spec.type}' 2>/dev/null || kubectl get svc -n "${NAMESPACE}" -l app=db -o jsonpath='{.items[0].spec.type}' 2>/dev/null || echo "")
if [[ "${svc_fe}" == "ClusterIP" && "${svc_api}" == "ClusterIP" && -n "${svc_db}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (frontend=${svc_fe:-none}, api=${svc_api:-none}, db=${svc_db:-none})"
    ((FAIL++))
fi

# --- Objective 5: HPA for API ---
echo -n "[5/7] HPA for API (min=2, max=8, cpu=70%): "
hpa_min=$(kubectl get hpa -n "${NAMESPACE}" -o jsonpath='{.items[0].spec.minReplicas}' 2>/dev/null || echo "")
hpa_max=$(kubectl get hpa -n "${NAMESPACE}" -o jsonpath='{.items[0].spec.maxReplicas}' 2>/dev/null || echo "")
if [[ "${hpa_min}" == "2" && "${hpa_max}" == "8" ]]; then
    echo "PASS (min=${hpa_min}, max=${hpa_max})"
    ((PASS++))
else
    echo "FAIL (min=${hpa_min:-none}, max=${hpa_max:-none})"
    ((FAIL++))
fi

# --- Objective 6: All pods Running ---
echo -n "[6/7] All pods Running and Ready: "
not_ready=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running" | wc -l)
if [[ ${not_ready} -eq 0 ]]; then
    total_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)
    echo "PASS (${total_pods} pods running)"
    ((PASS++))
else
    echo "FAIL (${not_ready} pods not Running)"
    ((FAIL++))
fi

# --- Objective 7: Frontend can reach API ---
echo -n "[7/7] Frontend can reach API via DNS: "
fe_pod=$(kubectl get pods -n "${NAMESPACE}" -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${fe_pod}" ]]; then
    response=$(kubectl exec -n "${NAMESPACE}" "${fe_pod}" -- wget -qO- --timeout=5 "http://api.${NAMESPACE}.svc.cluster.local:8080/" 2>/dev/null || echo "")
    if [[ -n "${response}" ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no response from API)"
        ((FAIL++))
    fi
else
    echo "FAIL (no frontend pod found)"
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
