#!/usr/bin/env bash
# Scenario: Observability-driven - logs missing from Loki
# Best diagnosed via Loki/Grafana queries and log pipeline inspection.

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops (logging pipeline)
  Symptom:  Grafana Explore shows no logs for grokdevops pods.
            kubectl logs works fine - the issue is in the collection pipeline.
  Impact:   Central logging is blind. Cannot search logs in Grafana.
  Hints:    kubectl logs works - so the app is logging. The problem is collection.
            Check log agent (Promtail/Alloy) config and pod annotations.
  Tools:    kubectl logs, kubectl get pods -n monitoring, Grafana Explore

  Suggested LogQL:
    {namespace="grokdevops"}     -- should return results but doesn't
    {job="grokdevops/*"}         -- try alternate label selectors
EOF
}

inject() {
  log_info "Adding annotation to suppress log collection..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"add","path":"/spec/template/metadata/annotations/promtail.io~1collect","value":"false"}]'
  log_ok "Log collection suppressed via pod annotation."
}

restore() {
  log_info "Removing log suppression annotation..."
  kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
    -p='[{"op":"remove","path":"/spec/template/metadata/annotations/promtail.io~1collect"}]' 2>/dev/null || true
  kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s || true
  log_ok "Restored."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local ann
    ann=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.metadata.annotations.promtail\.io/collect}' 2>/dev/null)
    [[ "$ann" == "false" ]]
  else
    local ann
    ann=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.metadata.annotations.promtail\.io/collect}' 2>/dev/null)
    [[ -z "$ann" || "$ann" == "true" ]]
  fi
}
