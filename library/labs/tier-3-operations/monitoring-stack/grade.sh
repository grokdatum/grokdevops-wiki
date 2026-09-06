#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-monitoring"
PASS=0
FAIL=0
TOTAL=7

echo "=== Monitoring Stack Lab — Grading ==="
echo ""

# --- Objective 1: Prometheus running ---
echo -n "[1/7] Prometheus is running: "
prom_pods=$(kubectl get pods -n "${NAMESPACE}" -l app=prometheus -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
if echo "${prom_pods}" | grep -q "Running"; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no running Prometheus pod with label app=prometheus)"
    ((FAIL++))
fi

# --- Objective 2: Pod discovery configured ---
echo -n "[2/7] Prometheus config has kubernetes pod discovery: "
config=$(kubectl get configmap prometheus-config -n "${NAMESPACE}" -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null || echo "")
if echo "${config}" | grep -q "kubernetes_sd_configs"; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no kubernetes_sd_configs in prometheus.yml)"
    ((FAIL++))
fi

# --- Objective 3: Alert rule for pod restarts ---
echo -n "[3/7] Alert rule for pod restarts exists: "
# Check ConfigMaps for alert rules
rules=$(kubectl get configmap -n "${NAMESPACE}" -o json 2>/dev/null | grep -c "restart" || echo 0)
if [[ ${rules} -gt 0 ]]; then
    echo "PASS"
    ((PASS++))
else
    # Also check if inline in prometheus config
    if echo "${config}" | grep -qi "restart"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no alert rule mentioning restarts found)"
        ((FAIL++))
    fi
fi

# --- Objective 4: Grafana running ---
echo -n "[4/7] Grafana is running: "
grafana_pods=$(kubectl get pods -n "${NAMESPACE}" -l app=grafana -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
if echo "${grafana_pods}" | grep -q "Running"; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no running Grafana pod with label app=grafana)"
    ((FAIL++))
fi

# --- Objective 5: Grafana has Prometheus datasource ---
echo -n "[5/7] Grafana configured with Prometheus datasource: "
grafana_ds=$(kubectl get configmap -n "${NAMESPACE}" -o json 2>/dev/null | grep -c "prometheus" || echo 0)
grafana_env=$(kubectl get deployment -n "${NAMESPACE}" -l app=grafana -o json 2>/dev/null | grep -c "prometheus" || echo 0)
if [[ $((grafana_ds + grafana_env)) -gt 0 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no Prometheus datasource configuration found)"
    ((FAIL++))
fi

# --- Objective 6: Dashboard ConfigMap exists ---
echo -n "[6/7] Dashboard ConfigMap exists: "
dashboard_cm=$(kubectl get configmap -n "${NAMESPACE}" -l grafana_dashboard=1 -o name 2>/dev/null || kubectl get configmap -n "${NAMESPACE}" -o name 2>/dev/null | grep -i dashboard || echo "")
if [[ -n "${dashboard_cm}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no dashboard ConfigMap found)"
    ((FAIL++))
fi

# --- Objective 7: Sample app with metrics annotation ---
echo -n "[7/7] Sample app with prometheus.io/scrape annotation: "
annotated=$(kubectl get pods -n "${NAMESPACE}" -o json 2>/dev/null | grep -c '"prometheus.io/scrape": "true"' || echo 0)
if [[ ${annotated} -gt 0 ]]; then
    echo "PASS (${annotated} pods with scrape annotation)"
    ((PASS++))
else
    # Check all namespaces
    annotated_all=$(kubectl get pods --all-namespaces -o json 2>/dev/null | grep -c '"prometheus.io/scrape": "true"' || echo 0)
    if [[ ${annotated_all} -gt 0 ]]; then
        echo "PASS (${annotated_all} annotated pods found)"
        ((PASS++))
    else
        echo "FAIL (no pod with prometheus.io/scrape annotation)"
        ((FAIL++))
    fi
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
