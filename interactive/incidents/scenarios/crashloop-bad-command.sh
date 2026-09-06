#!/usr/bin/env bash
# Scenario: CrashLoopBackOff - bad container command
# Runbook: training/library/runbooks/crashloopbackoff.md

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Pods are crash-looping; the application is unreachable.
  Impact:   100% of user traffic affected. Service returning 503s.
  Hints:    Check pod status, describe pod events, inspect container logs.
  Tools:    kubectl get pods, kubectl describe pod, kubectl logs
EOF
}

inject() {
  log_info "Patching deployment command to invalid binary..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["/bin/nonexistent-binary"]}]'
  log_ok "Pods will enter CrashLoopBackOff."
}

restore() {
  log_info "Removing invalid command override..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"remove","path":"/spec/template/spec/containers/0/command"}]'
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grokdevops -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null | grep -qi "CrashLoopBackOff"
  else
    local ready
    ready=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    [[ "${ready:-0}" -ge 1 ]]
  fi
}
