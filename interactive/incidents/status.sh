#!/usr/bin/env bash
# Show current incident status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

incident_parse_no_args "$@"

echo "============================================"
echo "  INCIDENT STATUS"
echo "============================================"
echo ""

if ! state_exists; then
  log_info "No active incident."
  exit 0
fi

active=$(state_get "incident_id")
ns=$(state_get "namespace")
started=$(state_get "started_at")
resolved=$(state_get "resolved")
dry_run_flag=$(state_get "dry_run")

echo "Incident:  $active"
echo "Namespace: $ns"
echo "Started:   $started"
echo "Resolved:  $resolved"
echo "Dry-run:   $dry_run_flag"

if [[ "$resolved" != "True" ]] && [[ -n "$started" ]]; then
  now_epoch=$(date -u +%s)
  start_epoch=$(date -u -d "$started" +%s 2>/dev/null || echo "$now_epoch")
  elapsed=$(( now_epoch - start_epoch ))
  mins=$(( elapsed / 60 ))
  secs=$(( elapsed % 60 ))
  echo "Elapsed:   ${mins}m ${secs}s"
fi

echo ""

# If cluster is reachable, show quick pod status
if kubectl cluster-info &>/dev/null 2>&1; then
  NAMESPACE="$ns"
  echo "--- Pod Status (${ns}) ---"
  kube_get pods -o wide 2>/dev/null || echo "  (unable to reach namespace)"
  echo ""
  echo "--- Recent Events ---"
  kube_get events --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "  (no events)"
fi
