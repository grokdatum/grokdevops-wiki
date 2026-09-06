#!/usr/bin/env bash
# Scenario: Readiness probe misconfigured - wrong HTTP path
# Runbook: training/library/runbooks/readiness_probe_failed.md
# Related: training/interactive/runtime-labs/lab-runtime-01-rollout-probe-failure/
# Related: training/interactive/chaos/scripts/break_readiness.sh (reuses same technique)

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  New pods not becoming Ready. Deployment rollout stalled.
  Impact:   Rolling update cannot complete. Old pods may still serve.
  Hints:    Check pod conditions. Look at readiness probe configuration.
  Tools:    kubectl describe pod, kubectl rollout status, kubectl get endpoints
EOF
}

inject() {
  log_info "Patching readiness probe to wrong path..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/nonexistent-health-check"}]'
  log_ok "Readiness probe broken."
}

restore() {
  log_info "Restoring readiness probe path to /health..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/health"}]'
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local path
    path=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
    [[ "$path" == "/nonexistent-health-check" ]]
  else
    local path
    path=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
    [[ "$path" == "/health" ]]
  fi
}
