#!/usr/bin/env bash
# Scenario: Observability-driven - Prometheus target down
# Requires checking Prometheus targets page, not just kubectl.

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops (monitoring)
  Symptom:  Prometheus target for grokdevops shows DOWN status.
            Application pods are Running and Ready.
  Impact:   All application metrics, alerts, and dashboards are stale/missing.
  Hints:    Pods are healthy. The issue is between Prometheus and the app.
            Check service ports, ServiceMonitor config, and Prometheus targets.
  Tools:    kubectl get servicemonitor -o yaml, Prometheus Targets UI

  Suggested PromQL:
    up{namespace="grokdevops"}                    -- should be 1, shows 0
    scrape_duration_seconds{job=~".*grokdevops.*"} -- check scrape errors
EOF
}

inject() {
  log_info "Breaking metrics port annotation on service..."
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"add","path":"/metadata/annotations/prometheus.io~1scrape","value":"false"}]'
  # Also break port name if ServiceMonitor relies on it
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/ports/0/name","value":"web-broken"}]' 2>/dev/null || true
  log_ok "Prometheus scraping broken via annotation and port name."
}

restore() {
  log_info "Restoring Prometheus scrape annotations and port name..."
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"remove","path":"/metadata/annotations/prometheus.io~1scrape"}]' 2>/dev/null || true
  kubectl patch service grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/ports/0/name","value":"http"}]' 2>/dev/null || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local ann
    ann=$(kubectl get svc grokdevops -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.prometheus\.io/scrape}' 2>/dev/null)
    [[ "$ann" == "false" ]]
  else
    local ann
    ann=$(kubectl get svc grokdevops -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.prometheus\.io/scrape}' 2>/dev/null)
    [[ -z "$ann" || "$ann" == "true" ]]
  fi
}
