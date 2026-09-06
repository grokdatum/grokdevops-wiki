#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-prr"
LAB_DIR="/tmp/lab-prr"
PASS=0
FAIL=0
TOTAL=9

echo "=== Production Readiness Review Lab — Grading ==="
echo ""

DEP="order-processor"

# --- Objective 1: Resource limits ---
echo -n "[1/9] Resource limits configured: "
mem_limit=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
cpu_limit=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
if [[ -n "${mem_limit}" && -n "${cpu_limit}" ]]; then
    echo "PASS (cpu=${cpu_limit}, memory=${mem_limit})"
    ((PASS++))
else
    echo "FAIL (cpu=${cpu_limit:-none}, memory=${mem_limit:-none})"
    ((FAIL++))
fi

# --- Objective 2: Multiple replicas + PDB ---
echo -n "[2/9] Replicas >= 2 with PDB: "
replicas=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
pdb=$(kubectl get pdb -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [[ "${replicas}" -ge 2 && ${pdb} -ge 1 ]]; then
    echo "PASS (replicas=${replicas}, PDB count=${pdb})"
    ((PASS++))
else
    echo "FAIL (replicas=${replicas}, PDB count=${pdb})"
    ((FAIL++))
fi

# --- Objective 3: Probes ---
echo -n "[3/9] Liveness and readiness probes: "
liveness=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' 2>/dev/null || echo "")
readiness=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
if [[ -n "${liveness}" && -n "${readiness}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (liveness=${liveness:+set}${liveness:-missing}, readiness=${readiness:+set}${readiness:-missing})"
    ((FAIL++))
fi

# --- Objective 4: Prometheus annotations ---
echo -n "[4/9] Prometheus scrape annotations: "
scrape=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.metadata.annotations.prometheus\.io/scrape}' 2>/dev/null || echo "")
if [[ "${scrape}" == "true" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (prometheus.io/scrape=${scrape:-not set})"
    ((FAIL++))
fi

# --- Objective 5: Security context ---
echo -n "[5/9] Security context (non-root, read-only FS): "
non_root=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null || echo "")
ro_fs=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null || echo "")
# Also check pod-level security context
if [[ -z "${non_root}" ]]; then
    non_root=$(kubectl get deployment "${DEP}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "")
fi
if [[ "${non_root}" == "true" ]]; then
    echo "PASS (nonRoot=true, readOnlyFS=${ro_fs})"
    ((PASS++))
else
    echo "FAIL (nonRoot=${non_root:-not set})"
    ((FAIL++))
fi

# --- Objective 6: NetworkPolicy ---
echo -n "[6/9] NetworkPolicy configured: "
np_count=$(kubectl get networkpolicy -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [[ ${np_count} -ge 1 ]]; then
    echo "PASS (${np_count} policies)"
    ((PASS++))
else
    echo "FAIL (no NetworkPolicy found)"
    ((FAIL++))
fi

# --- Objective 7: Runbook ---
echo -n "[7/9] Runbook exists: "
if [[ -f "${LAB_DIR}/runbook.md" ]]; then
    size=$(wc -c < "${LAB_DIR}/runbook.md")
    if [[ ${size} -ge 200 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need at least 200)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/runbook.md not found)"
    ((FAIL++))
fi

# --- Objective 8: PRR report ---
echo -n "[8/9] PRR report exists: "
if [[ -f "${LAB_DIR}/prr-report.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/prr-report.txt")
    if [[ ${size} -ge 300 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need at least 300)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/prr-report.txt not found)"
    ((FAIL++))
fi

# --- Objective 9: All pods healthy ---
echo -n "[9/9] All pods Running and Ready: "
not_ready=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running" | wc -l)
running=$(kubectl get pods -n "${NAMESPACE}" -l app=order-processor --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${not_ready} -eq 0 && ${running} -ge 2 ]]; then
    echo "PASS (${running} pods)"
    ((PASS++))
else
    echo "FAIL (${running} running, ${not_ready} unhealthy)"
    ((FAIL++))
fi

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Passed: ${PASS}/${TOTAL}"
echo "Failed: ${FAIL}/${TOTAL}"

if [[ ${PASS} -eq ${TOTAL} ]]; then
    echo "Status: ALL OBJECTIVES COMPLETE — SERVICE APPROVED FOR PRODUCTION"
    exit 0
else
    echo "Status: INCOMPLETE — PRR NOT APPROVED"
    exit 1
fi
