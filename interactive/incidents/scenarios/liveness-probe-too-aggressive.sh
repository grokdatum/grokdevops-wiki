#!/usr/bin/env bash
# Scenario: Liveness probe too aggressive - causes restart loops

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Pods repeatedly restarting. Restart count climbing rapidly.
  Impact:   Service flapping. Intermittent 503 responses.
  Hints:    Check restart count. Look at liveness probe settings and timing.
  Tools:    kubectl describe pod, kubectl get pods, kubectl get events
EOF
}

inject() {
  log_info "Setting liveness probe to very aggressive timing..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/initialDelaySeconds","value":0},
         {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/periodSeconds","value":1},
         {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/timeoutSeconds","value":1},
         {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/failureThreshold","value":1}]'
  log_ok "Liveness probe set to extremely aggressive timing."
}

restore() {
  log_info "Restoring liveness probe to sane defaults..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/initialDelaySeconds","value":10},
         {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/periodSeconds","value":10},
         {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/timeoutSeconds","value":3},
         {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/failureThreshold","value":3}]'
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local ft
    ft=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.failureThreshold}' 2>/dev/null || echo "3")
    [[ "$ft" == "1" ]]
  else
    local ft
    ft=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.failureThreshold}' 2>/dev/null || echo "3")
    [[ "$ft" -ge 3 ]]
  fi
}
