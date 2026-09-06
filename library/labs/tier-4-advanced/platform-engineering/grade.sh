#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-platform"
LAB_DIR="/tmp/lab-platform"
PASS=0
FAIL=0
TOTAL=7

echo "=== Platform Engineering Lab — Grading ==="
echo ""

# --- Objective 1: Chart has required templates ---
echo -n "[1/7] Chart has deployment, service, hpa, pdb templates: "
tmpl_dir="${LAB_DIR}/charts/service-template/templates"
has_deploy=$(ls "${tmpl_dir}/"*deploy* 2>/dev/null | wc -l)
has_svc=$(ls "${tmpl_dir}/"*service* 2>/dev/null | wc -l)
has_hpa=$(ls "${tmpl_dir}/"*hpa* 2>/dev/null | wc -l)
has_pdb=$(ls "${tmpl_dir}/"*pdb* 2>/dev/null | wc -l)
total_tmpl=$((has_deploy + has_svc + has_hpa + has_pdb))
if [[ ${total_tmpl} -ge 4 ]]; then
    echo "PASS (${total_tmpl} templates)"
    ((PASS++))
else
    echo "FAIL (deploy=${has_deploy}, svc=${has_svc}, hpa=${has_hpa}, pdb=${has_pdb})"
    ((FAIL++))
fi

# --- Objective 2: values.yaml has sensible defaults ---
echo -n "[2/7] values.yaml has resource defaults: "
values="${LAB_DIR}/charts/service-template/values.yaml"
if [[ -f "${values}" ]]; then
    has_resources=$(grep -c "resources\|memory\|cpu" "${values}" || echo 0)
    if [[ ${has_resources} -ge 2 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no resource defaults found)"
        ((FAIL++))
    fi
else
    echo "FAIL (values.yaml not found)"
    ((FAIL++))
fi

# --- Objective 3: Chart includes probes ---
echo -n "[3/7] Chart includes health check probes: "
probe_count=0
for f in "${tmpl_dir}"/*.yaml; do
    [[ -f "${f}" ]] && probe_count=$((probe_count + $(grep -c "Probe\|livenessProbe\|readinessProbe" "${f}" || echo 0)))
done
if [[ ${probe_count} -ge 1 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no probe references in templates)"
    ((FAIL++))
fi

# --- Objective 4: Prometheus annotations support ---
echo -n "[4/7] Chart supports Prometheus annotations: "
prom_count=0
for f in "${tmpl_dir}"/*.yaml; do
    [[ -f "${f}" ]] && prom_count=$((prom_count + $(grep -c "prometheus.io" "${f}" || echo 0)))
done
if [[ ${prom_count} -ge 1 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no prometheus.io annotations in templates)"
    ((FAIL++))
fi

# --- Objective 5: team-alpha release running ---
echo -n "[5/7] team-alpha Helm release running: "
alpha_status=$(helm status team-alpha -n "${NAMESPACE}" -o json 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 || echo "")
alpha_pods=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/instance=team-alpha" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${alpha_pods} -ge 1 ]] || echo "${alpha_status}" | grep -q "deployed"; then
    echo "PASS (${alpha_pods} pods)"
    ((PASS++))
else
    echo "FAIL (release not found or no running pods)"
    ((FAIL++))
fi

# --- Objective 6: team-beta release running ---
echo -n "[6/7] team-beta Helm release running: "
beta_pods=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/instance=team-beta" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${beta_pods} -ge 1 ]]; then
    echo "PASS (${beta_pods} pods)"
    ((PASS++))
else
    echo "FAIL (no running pods for team-beta)"
    ((FAIL++))
fi

# --- Objective 7: Both instances have different images ---
echo -n "[7/7] Instances use different images: "
alpha_img=$(kubectl get deployment -n "${NAMESPACE}" -l "app.kubernetes.io/instance=team-alpha" -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
beta_img=$(kubectl get deployment -n "${NAMESPACE}" -l "app.kubernetes.io/instance=team-beta" -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
if [[ -n "${alpha_img}" && -n "${beta_img}" && "${alpha_img}" != "${beta_img}" ]]; then
    echo "PASS (alpha=${alpha_img}, beta=${beta_img})"
    ((PASS++))
else
    echo "FAIL (alpha=${alpha_img:-none}, beta=${beta_img:-none})"
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
