#!/usr/bin/env bash
# Scenario: Observability-driven - latency spike from resource starvation
# This incident is best diagnosed via Prometheus/Grafana, not just kubectl.

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Application responding slowly. P99 latency spiking.
            Pods appear Running and Ready.
  Impact:   User-facing latency degradation. SLO violations likely.
  Hints:    kubectl alone won't explain WHY. Use Prometheus and Grafana.
            Check CPU throttling and request duration histograms.
  Tools:    kubectl top pods, Grafana dashboards, Prometheus queries

  Suggested PromQL:
    rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
    container_cpu_cfs_throttled_periods_total / container_cpu_cfs_periods_total
EOF
}

inject() {
  log_info "Setting CPU limit very low to cause throttling and latency..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"10m"}]'
  log_ok "CPU limits set extremely low - expect high latency from throttling."
}

restore() {
  log_info "Restoring CPU limits..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"500m"}]'
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local limit
    limit=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
    [[ "$limit" == "10m" ]]
  else
    local limit
    limit=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
    [[ "$limit" != "10m" ]]
  fi
}
