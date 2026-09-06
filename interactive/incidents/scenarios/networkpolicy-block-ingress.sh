#!/usr/bin/env bash
# Scenario: NetworkPolicy blocking all ingress traffic
# Runbook: training/library/runbooks/networkpolicy_block.md
# Related: training/interactive/chaos/scripts/toggle_networkpolicy.sh

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Pods are Running and Ready but service is unreachable.
  Impact:   All inbound traffic to the application is blocked.
  Hints:    Pods look healthy. Service and endpoints exist. Check network policies.
  Tools:    kubectl get networkpolicy, kubectl describe networkpolicy, kubectl get endpoints
EOF
}

POLICY_NAME="incident-deny-all-ingress"

inject() {
  log_info "Applying deny-all ingress NetworkPolicy..."
  kubectl apply -n "$NAMESPACE" -f - <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${POLICY_NAME}
  labels:
    incident-simulator: "true"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: grokdevops
  policyTypes:
    - Ingress
  ingress: []
YAML
  log_ok "NetworkPolicy applied - all ingress blocked."
}

restore() {
  log_info "Removing deny-all NetworkPolicy..."
  kubectl delete networkpolicy "$POLICY_NAME" -n "$NAMESPACE" --ignore-not-found
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" &>/dev/null
  else
    ! kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" &>/dev/null
  fi
}
