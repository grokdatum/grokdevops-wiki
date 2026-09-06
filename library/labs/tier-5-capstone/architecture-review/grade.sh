#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-arch-review"
LAB_DIR="/tmp/lab-arch"
PASS=0
FAIL=0
TOTAL=8

echo "=== Architecture Review Lab — Grading ==="
echo ""

# --- Objective 1: Review document ---
echo -n "[1/8] Architecture review document exists: "
if [[ -f "${LAB_DIR}/review.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/review.txt")
    if [[ ${size} -ge 500 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need 500+)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/review.txt not found)"
    ((FAIL++))
fi

# --- Objective 2: No single-replica deployments (except DB) ---
echo -n "[2/8] No single points of failure (replicas >= 2 for stateless): "
api_replicas=$(kubectl get deployment monolith-api -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 1)
fe_replicas=$(kubectl get deployment frontend -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 1)
if [[ "${api_replicas}" -ge 2 && "${fe_replicas}" -ge 2 ]]; then
    echo "PASS (api=${api_replicas}, frontend=${fe_replicas})"
    ((PASS++))
else
    echo "FAIL (api=${api_replicas}, frontend=${fe_replicas})"
    ((FAIL++))
fi

# --- Objective 3: Resource limits on all deployments ---
echo -n "[3/8] Resource limits on all services: "
limits_found=0
for dep in monolith-api database frontend; do
    ml=$(kubectl get deployment "${dep}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
    [[ -n "${ml}" ]] && ((limits_found++))
done
if [[ ${limits_found} -ge 3 ]]; then
    echo "PASS (${limits_found}/3 have limits)"
    ((PASS++))
else
    echo "FAIL (${limits_found}/3 have limits)"
    ((FAIL++))
fi

# --- Objective 4: Probes on stateless services ---
echo -n "[4/8] Health probes on API and frontend: "
api_probe=$(kubectl get deployment monolith-api -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
fe_probe=$(kubectl get deployment frontend -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
if [[ -n "${api_probe}" && -n "${fe_probe}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (api=${api_probe:+set}${api_probe:-missing}, fe=${fe_probe:+set}${fe_probe:-missing})"
    ((FAIL++))
fi

# --- Objective 5: Cache layer deployed ---
echo -n "[5/8] Caching layer (Redis) deployed: "
cache_pods=$(kubectl get pods -n "${NAMESPACE}" -l app=cache --no-headers 2>/dev/null | wc -l || echo 0)
if [[ ${cache_pods} -eq 0 ]]; then
    cache_pods=$(kubectl get pods -n "${NAMESPACE}" -l app=redis --no-headers 2>/dev/null | wc -l || echo 0)
fi
if [[ ${cache_pods} -ge 1 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no cache/redis pods found — label with app=cache or app=redis)"
    ((FAIL++))
fi

# --- Objective 6: NetworkPolicies ---
echo -n "[6/8] NetworkPolicies configured: "
np_count=$(kubectl get networkpolicy -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [[ ${np_count} -ge 1 ]]; then
    echo "PASS (${np_count} policies)"
    ((PASS++))
else
    echo "FAIL (no NetworkPolicies)"
    ((FAIL++))
fi

# --- Objective 7: Separate services ---
echo -n "[7/8] At least 4 services defined: "
svc_count=$(kubectl get svc -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [[ ${svc_count} -ge 4 ]]; then
    echo "PASS (${svc_count} services)"
    ((PASS++))
else
    echo "FAIL (${svc_count} services — need 4+)"
    ((FAIL++))
fi

# --- Objective 8: All pods healthy ---
echo -n "[8/8] All pods Running: "
not_running=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running" | wc -l)
total=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)
if [[ ${not_running} -eq 0 && ${total} -ge 4 ]]; then
    echo "PASS (${total} pods all Running)"
    ((PASS++))
else
    echo "FAIL (${total} total, ${not_running} not running)"
    ((FAIL++))
fi

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Passed: ${PASS}/${TOTAL}"
echo "Failed: ${FAIL}/${TOTAL}"

if [[ ${PASS} -eq ${TOTAL} ]]; then
    echo "Status: ARCHITECTURE REVIEW COMPLETE — ALL FIXES VERIFIED"
    exit 0
else
    echo "Status: REVIEW INCOMPLETE"
    exit 1
fi
