#!/usr/bin/env bash
# Scenario: Service port mismatch - targetPort doesn't match container port
# (Replaces ingress-misroute since ingress is disabled by default)

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Service exists with endpoints, but connections are refused.
  Impact:   All traffic gets "connection refused" errors.
  Hints:    Check service ports vs container ports. The service forwards to the wrong port.
  Tools:    kubectl get svc -o yaml, kubectl describe svc, kubectl get pods -o yaml
EOF
}

inject() {
  log_info "Changing service targetPort to wrong value..."
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":9999}]'
  log_ok "Service targetPort broken."
}

restore() {
  log_info "Restoring service targetPort to 8000..."
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":8000}]'
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local port
    port=$(kubectl get svc grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
    [[ "$port" == "9999" ]]
  else
    local port
    port=$(kubectl get svc grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
    [[ "$port" == "8000" ]]
  fi
}
