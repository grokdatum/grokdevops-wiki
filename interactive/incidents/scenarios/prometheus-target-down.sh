#!/usr/bin/env bash
# Scenario: Prometheus target down - ServiceMonitor selector mismatch
# Runbook: training/library/runbooks/prometheus_target_down.md
# Related: training/interactive/runtime-labs/lab-runtime-03-observability-target-down/

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops (monitoring)
  Symptom:  Prometheus shows grokdevops target as DOWN. No application metrics.
  Impact:   Alerting and dashboards for the application are blind.
  Hints:    Check ServiceMonitor labels vs Prometheus serviceMonitorSelector.
            Look at Prometheus targets page or API.
  Tools:    kubectl get servicemonitor -o yaml, kubectl get prometheus -o yaml
  PromQL:   up{job="grokdevops"} should return 0 or no data
EOF
}

inject() {
  log_info "Patching ServiceMonitor with wrong label selector..."
  if kubectl get servicemonitor grokdevops -n "$NAMESPACE" &>/dev/null; then
    kubectl patch servicemonitor grokdevops -n "$NAMESPACE" --type=json \
      -p='[{"op":"replace","path":"/spec/selector/matchLabels/app.kubernetes.io~1name","value":"grokdevops-wrong-label"}]'
  else
    kubectl apply -n "$NAMESPACE" -f - <<YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: grokdevops
  labels:
    incident-simulator: "true"
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: grokdevops-wrong-label
  endpoints:
    - port: http
      interval: 30s
YAML
  fi
  log_ok "ServiceMonitor selector broken."
}

restore() {
  log_info "Restoring ServiceMonitor selector..."
  if kubectl get servicemonitor grokdevops -n "$NAMESPACE" &>/dev/null; then
    kubectl patch servicemonitor grokdevops -n "$NAMESPACE" --type=json \
      -p='[{"op":"replace","path":"/spec/selector/matchLabels/app.kubernetes.io~1name","value":"grokdevops"}]'
  fi
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local label
    label=$(kubectl get servicemonitor grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.selector.matchLabels.app\.kubernetes\.io/name}' 2>/dev/null)
    [[ "$label" == "grokdevops-wrong-label" ]]
  else
    local label
    label=$(kubectl get servicemonitor grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.selector.matchLabels.app\.kubernetes\.io/name}' 2>/dev/null)
    [[ "$label" == "grokdevops" ]]
  fi
}
