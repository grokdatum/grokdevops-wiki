#!/usr/bin/env bash
# Challenge Mode - Time-boxed incident response training
#
# Usage:
#   ./challenge.sh --yes                    # 10 min default
#   ./challenge.sh --yes --minutes 15       # custom time
#   ./challenge.sh --yes --incident crashloop-bad-command
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

incident_parse_args "$@"
check_namespace_approved "$NAMESPACE"

echo "============================================"
echo "  INCIDENT CHALLENGE MODE"
echo "============================================"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Challenge mode requires --yes to inject a real incident."
  log_dry "Usage: $0 --yes [--minutes N] [--incident ID]"
  echo ""
  echo "Available scenarios:"
  list_scenarios | sed 's/^/  /'
  exit 0
fi

# Check for active incident
if state_exists; then
  active=$(state_get "incident_id")
  resolved=$(state_get "resolved")
  if [[ "$resolved" != "True" ]] && [[ -n "$active" ]]; then
    log_warn "An incident is already active: $active"
    log_warn "Restore first: make incident-restore YES=1"
    exit 1
  fi
fi

check_cluster
check_stack_deployed

# Select and inject
SELECTED=$(select_scenario)
SCENARIO_FILE="${SCENARIOS_DIR}/${SELECTED}.sh"
source "$SCENARIO_FILE"

log_info "Injecting incident..."
inject
state_write "$SELECTED" "$NAMESPACE" "false"

echo ""
echo "============================================"
echo "  CHALLENGE STARTED"
echo "============================================"
echo ""
echo "  Time limit: ${MINUTES} minutes"
echo "  Started:    $(date -u +%H:%M:%S) UTC"
echo ""
echo "============================================"
echo "  INCIDENT BRIEFING"
echo "============================================"
incident_brief
echo "============================================"
echo ""
echo "Allowed tools:"
echo "  kubectl, helm, curl, logs, events, describe"
echo "  Grafana, Prometheus, Loki (if deployed)"
echo ""
echo "Commands:"
echo "  make incident-status     - Check status + elapsed time"
echo "  make incident-forensics  - Capture evidence bundle"
echo "  make incident-resolve    - Mark as resolved (when fixed)"
echo "  make incident-restore YES=1 - Give up and restore"
echo ""
echo "Good luck!"
