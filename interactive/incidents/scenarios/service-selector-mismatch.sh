#!/usr/bin/env bash
# Scenario: Service selector mismatch - service routes to no pods

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Service exists but returns no responses. Endpoints list is empty.
  Impact:   100% of traffic affected. Application appears down.
  Hints:    Compare service selector labels with pod labels. Check endpoints.
  Tools:    kubectl get svc -o yaml, kubectl get endpoints, kubectl get pods --show-labels
EOF
}

inject() {
  log_info "Patching service selector to non-matching label..."
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/selector/app.kubernetes.io~1name","value":"grokdevops-typo-wrong"}]'
  log_ok "Service selector broken - no endpoints will match."
}

restore() {
  log_info "Restoring service selector..."
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/selector/app.kubernetes.io~1name","value":"grokdevops"}]'
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local ep_count
    ep_count=$(kubectl get endpoints grokdevops -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null | wc -c)
    [[ "$ep_count" -le 2 ]]
  else
    local ep_count
    ep_count=$(kubectl get endpoints grokdevops -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null | wc -c)
    [[ "$ep_count" -gt 2 ]]
  fi
}
