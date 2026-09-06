#!/usr/bin/env bash
# Scenario: HPA not scaling - metrics API broken
# Runbook: training/library/runbooks/hpa_not_scaling.md
# Related: training/interactive/runtime-labs/lab-runtime-02-hpa-live-scaling/

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops (autoscaling)
  Symptom:  HPA shows <unknown> for CPU metrics. Pods not scaling under load.
  Impact:   Application cannot autoscale. Risk of overload under traffic spikes.
  Hints:    Check HPA status. Verify metrics-server is running. Check resource requests.
  Tools:    kubectl get hpa, kubectl describe hpa, kubectl top pods, kubectl get pods -n kube-system
EOF
}

inject() {
  log_info "Enabling HPA then breaking resource requests..."
  # Ensure HPA exists
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"0m"}]' 2>/dev/null || \
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=strategic \
    -p='{"spec":{"template":{"spec":{"containers":[{"name":"grokdevops","resources":{"requests":{"cpu":"0m"}}}]}}}}'

  # Create or update HPA
  kubectl apply -n "$NAMESPACE" -f - <<YAML
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: grokdevops
  labels:
    incident-simulator: "true"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: grokdevops
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
YAML
  log_ok "HPA created with zero CPU requests - metrics will show <unknown>."
}

restore() {
  log_info "Restoring CPU requests and cleaning up HPA..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"}]'
  kubectl delete hpa grokdevops -n "$NAMESPACE" --ignore-not-found
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local cpu_req
    cpu_req=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    [[ "$cpu_req" == "0m" || "$cpu_req" == "0" ]]
  else
    local cpu_req
    cpu_req=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    [[ "$cpu_req" != "0m" && "$cpu_req" != "0" && -n "$cpu_req" ]]
  fi
}
