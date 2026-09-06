#!/usr/bin/env bash
# Scenario: DNS resolution failure - bad service name in config
# Runbook: training/library/runbooks/dns_resolution.md

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Application logs show DNS resolution failures for backend calls.
  Impact:   Features depending on backend connectivity are broken.
  Hints:    Check application environment variables or configmaps for URLs.
            Look for DNS-related errors in pod logs.
  Tools:    kubectl logs, kubectl get configmap, kubectl describe pod
EOF
}

inject() {
  log_info "Creating configmap with bad service endpoint..."
  kubectl create configmap grokdevops-incident-dns \
    --from-literal=BACKEND_URL="http://grokdevops-backend-typo.${NAMESPACE}.svc.cluster.local:8080" \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/envFrom","value":[{"configMapRef":{"name":"grokdevops-incident-dns"}}]}]'
  log_ok "DNS misconfiguration injected via configmap."
}

restore() {
  log_info "Removing bad DNS configmap reference..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"remove","path":"/spec/template/spec/containers/0/envFrom"}]' 2>/dev/null || true
  kubectl delete configmap grokdevops-incident-dns -n "$NAMESPACE" --ignore-not-found
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    kubectl get configmap grokdevops-incident-dns -n "$NAMESPACE" &>/dev/null
  else
    ! kubectl get configmap grokdevops-incident-dns -n "$NAMESPACE" &>/dev/null
  fi
}
