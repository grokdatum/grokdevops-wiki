#!/usr/bin/env bash
# Scenario: Loki not receiving logs - pipeline label mismatch
# Runbook: training/library/runbooks/loki_no_logs.md
# Related: training/interactive/runtime-labs/lab-runtime-04-loki-no-logs/

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops (logging)
  Symptom:  No logs appearing in Loki/Grafana for grokdevops namespace.
  Impact:   Cannot troubleshoot application issues via log queries.
  Hints:    Check if Promtail/log agent is running. Check pipeline config.
            Verify log labels match your Loki queries.
  Tools:    kubectl get pods -n monitoring, kubectl logs (promtail), Loki query
  LogQL:    {namespace="grokdevops"} should return results but doesn't
EOF
}

inject() {
  log_info "Adding label to pods that breaks log pipeline matching..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"add","path":"/spec/template/metadata/annotations/logging.excluded","value":"true"}]'
  # Also add a misconfigured promtail relabel configmap if promtail exists
  kubectl create configmap incident-loki-note \
    --from-literal=NOTE="Log pipeline broken by annotation 'logging.excluded=true'" \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -
  log_ok "Logging pipeline disrupted."
}

restore() {
  log_info "Removing logging exclusion annotation..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"remove","path":"/spec/template/metadata/annotations/logging.excluded"}]' 2>/dev/null || true
  kubectl delete configmap incident-loki-note -n "$NAMESPACE" --ignore-not-found
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local ann
    ann=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.metadata.annotations.logging\.excluded}' 2>/dev/null)
    [[ "$ann" == "true" ]]
  else
    local ann
    ann=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.metadata.annotations.logging\.excluded}' 2>/dev/null)
    [[ -z "$ann" ]]
  fi
}
