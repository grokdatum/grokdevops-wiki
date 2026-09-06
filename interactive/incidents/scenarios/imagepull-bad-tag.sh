#!/usr/bin/env bash
# Scenario: ImagePullBackOff - bad image tag
# Runbook: training/library/runbooks/imagepullbackoff.md

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Pods stuck in ImagePullBackOff. New pods cannot start.
  Impact:   Deployment is stalled. Existing pods (if any) still serving.
  Hints:    Check pod events for image pull errors. Inspect the image tag.
  Tools:    kubectl describe pod, kubectl get events, kubectl get deployment -o yaml
EOF
}

inject() {
  log_info "Setting image tag to nonexistent version..."
  kubectl set image deployment/grokdevops -n "$NAMESPACE" \
    grokdevops=grokdevops:v99.99.99-does-not-exist
  log_ok "Image tag set to nonexistent version."
}

restore() {
  log_info "Restoring image tag to latest..."
  kubectl set image deployment/grokdevops -n "$NAMESPACE" \
    grokdevops=grokdevops:latest
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grokdevops -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null | grep -qiE "ImagePullBackOff|ErrImagePull"
  else
    local ready
    ready=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    [[ "${ready:-0}" -ge 1 ]]
  fi
}
