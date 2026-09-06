#!/usr/bin/env bash
# Scenario: OOMKilled - memory limit too low
# Runbook: training/library/runbooks/oomkilled.md
# Related lab: training/interactive/runtime-labs/lab-runtime-08-resource-limits-oom/

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Pods are being OOMKilled and restarting frequently.
  Impact:   Intermittent availability. Users see sporadic 503 errors.
  Hints:    Check pod status for OOMKilled reason. Look at resource limits.
  Tools:    kubectl describe pod, kubectl top pods, kubectl get events
EOF
}

inject() {
  log_info "Setting memory limit to 4Mi to trigger OOMKill..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"4Mi"},
         {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"4Mi"}]'
  log_ok "Memory limits set dangerously low."
}

restore() {
  log_info "Restoring memory limits to 512Mi/128Mi..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"512Mi"},
         {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"128Mi"}]'
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grokdevops -o jsonpath='{.items[*].status.containerStatuses[*].lastState.terminated.reason}' 2>/dev/null | grep -qi "OOMKilled"
  else
    local ready
    ready=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    [[ "${ready:-0}" -ge 1 ]]
  fi
}
