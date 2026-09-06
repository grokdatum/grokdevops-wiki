#!/usr/bin/env bash
# Scenario: Tempo trace receiver disabled - no traces collected
# Runbook: training/library/runbooks/tempo_no_traces.md

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops (tracing)
  Symptom:  No traces appearing in Tempo/Grafana. Trace search returns empty.
  Impact:   Cannot trace request flows for debugging latency or errors.
  Hints:    Check if Tempo is running. Verify the OTLP receiver configuration.
            Check if application is configured to send traces to the right endpoint.
  Tools:    kubectl get pods -n monitoring, kubectl logs (tempo), kubectl get svc -n monitoring
EOF
}

inject() {
  log_info "Injecting bad tracing endpoint into application config..."
  kubectl create configmap grokdevops-incident-traces \
    --from-literal=OTEL_EXPORTER_OTLP_ENDPOINT="http://tempo-nonexistent.monitoring.svc.cluster.local:4317" \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -n "$NAMESPACE" -f -
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/envFrom/-","value":{"configMapRef":{"name":"grokdevops-incident-traces"}}}]' 2>/dev/null || \
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/envFrom","value":[{"configMapRef":{"name":"grokdevops-incident-traces"}}]}]'
  log_ok "Tracing endpoint misconfigured."
}

restore() {
  log_info "Removing bad tracing configmap..."
  # Note: removes entire envFrom array; safe here because inject() is the only source
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"remove","path":"/spec/template/spec/containers/0/envFrom"}]' 2>/dev/null || true
  kubectl delete configmap grokdevops-incident-traces -n "$NAMESPACE" --ignore-not-found
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    kubectl get configmap grokdevops-incident-traces -n "$NAMESPACE" &>/dev/null
  else
    ! kubectl get configmap grokdevops-incident-traces -n "$NAMESPACE" &>/dev/null
  fi
}
