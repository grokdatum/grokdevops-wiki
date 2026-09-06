#!/usr/bin/env bash
# Collect forensics evidence bundle for the active incident
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

incident_parse_args "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"

# Determine output dir
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
FORENSICS_DIR="${SCRIPT_DIR}/../forensics/${TIMESTAMP}"
mkdir -p "$FORENSICS_DIR"

echo "============================================"
echo "  FORENSICS CAPTURE"
echo "============================================"
echo ""
log_info "Output: $FORENSICS_DIR"
echo ""

# Copy state if present
if state_exists; then
  cp "$STATE_FILE" "$FORENSICS_DIR/incident.json"
  log_ok "State file captured"
fi

# Best-effort collection - failures don't abort
collect() {
  local label="$1"
  local outfile="$2"
  shift 2
  if "$@" > "$FORENSICS_DIR/$outfile" 2>&1; then
    log_ok "$label"
  else
    log_warn "$label (partial or failed)"
  fi
}

if kubectl cluster-info &>/dev/null 2>&1; then
  collect "kubectl get all"       "kubectl.get.all.txt"     kubectl get all -n "$NAMESPACE" -o wide
  collect "kubectl get events"    "events.txt"              kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp'
  collect "kubectl describe pods" "describe.pods.txt"       kubectl describe pods -n "$NAMESPACE"
  collect "kubectl top pods"      "top.pods.txt"            kubectl top pods -n "$NAMESPACE"
  collect "kubectl top nodes"     "top.nodes.txt"           kubectl top nodes
  collect "helm list"             "helm.list.txt"           helm list -n "$NAMESPACE"

  # Helm history for grokdevops release
  collect "helm history"          "helm.history.grokdevops.txt"  helm history grokdevops -n "$NAMESPACE"

  # Pod logs (best-effort, limit to 200 lines per pod)
  mkdir -p "$FORENSICS_DIR/logs"
  for pod in $(kubectl get pods -n "$NAMESPACE" -o name 2>/dev/null | head -10); do
    pod_name=$(basename "$pod")
    kubectl logs "$pod" -n "$NAMESPACE" --tail=200 > "$FORENSICS_DIR/logs/${pod_name}.log" 2>&1 || true
    # Previous container logs
    kubectl logs "$pod" -n "$NAMESPACE" --previous --tail=100 > "$FORENSICS_DIR/logs/${pod_name}.previous.log" 2>&1 || true
  done
  log_ok "Pod logs captured"

  # Monitoring namespace (if exists)
  if kubectl get namespace monitoring &>/dev/null 2>&1; then
    collect "monitoring pods"     "monitoring.pods.txt"     kubectl get pods -n monitoring -o wide
  fi
else
  log_warn "Cannot reach cluster - skipping kubectl captures"
fi

echo ""
log_ok "Forensics bundle: $FORENSICS_DIR"
echo ""
ls -la "$FORENSICS_DIR/"
