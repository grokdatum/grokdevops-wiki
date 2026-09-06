#!/usr/bin/env bash
# Scenario: Helm upgrade with bad values - requires rollback
# Runbook: training/library/runbooks/helm_upgrade_failed.md
# Related: training/interactive/runtime-labs/lab-runtime-05-helm-upgrade-rollback/

incident_brief() {
  cat <<'EOF'
  Service:  grokdevops
  Symptom:  Recent helm upgrade caused deployment failure. Pods crashing.
  Impact:   Application is down after a deployment change.
  Hints:    Check helm history. Compare current vs previous revision values.
  Tools:    helm history, helm rollback, helm get values, kubectl get events
EOF
}

inject() {
  log_info "Performing helm upgrade with bad values..."
  helm upgrade grokdevops devops/helm/grokdevops -n "$NAMESPACE" \
    --reuse-values \
    --set image.tag="v0.0.0-broken-tag-does-not-exist" \
    --set resources.limits.memory="2Mi" \
    --wait=false
  log_ok "Bad helm upgrade applied."
}

restore() {
  log_info "Rolling back helm release..."
  local current_rev
  current_rev=$(helm history grokdevops -n "$NAMESPACE" --max 1 -o json 2>/dev/null | python3 -c "import json,sys; h=json.load(sys.stdin); print(h[0]['revision'])" 2>/dev/null || echo "1")
  local rollback_rev=$(( current_rev - 1 ))
  if [[ $rollback_rev -lt 1 ]]; then
    rollback_rev=1
  fi
  helm rollback grokdevops "$rollback_rev" -n "$NAMESPACE" --wait --timeout=120s
  log_ok "Rolled back to revision $rollback_rev."
}

verify() {
  local mode="${1:-broken}"
  if [[ "$mode" == "broken" ]]; then
    local tag
    tag=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    echo "$tag" | grep -q "broken-tag"
  else
    local ready
    ready=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    [[ "${ready:-0}" -ge 1 ]]
  fi
}
