#!/usr/bin/env bash
# Scenario: CPU spike causing pod restarts and HPA oscillation
# Related: training/interactive/chaos/scripts/cpu_stress.sh

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  High CPU usage on pods. Pods may be OOMKilled or restarting.
            HPA may be scaling up and down erratically.
  Impact:   Degraded performance. Increased latency and error rates.
  Hints:    Check resource usage. Look at CPU limits vs actual usage.
            Investigate what's consuming CPU.
  Tools:    kubectl top pods, kubectl describe pod, kubectl get hpa, kubectl get events
EOF
}

inject() {
  log_info "Setting very low CPU limits to simulate spike-induced throttling..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"5m"},
         {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"5m"}]'
  log_ok "CPU limits set extremely low - pods will be severely throttled."
}

restore() {
  log_info "Restoring CPU limits..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"500m"},
         {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"}]'
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local limit
    limit=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
    [[ "$limit" == "5m" ]]
  else
    local limit
    limit=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
    [[ "$limit" != "5m" ]]
  fi
}
