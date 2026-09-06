#!/usr/bin/env bash
# Incident Simulator - Main Entrypoint
# Selects and injects a random (or specific) incident for training.
#
# Usage:
#   ./incident.sh                  # dry-run, random incident
#   ./incident.sh --yes            # inject random incident
#   ./incident.sh --incident crashloop-bad-command --yes
#   ./incident.sh --seed 42        # reproducible selection
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

incident_parse_args "$@"
check_namespace_approved "$NAMESPACE"

echo "============================================"
echo "  INCIDENT SIMULATOR"
echo "============================================"
echo ""

# Check for active incident
if state_exists; then
  active=$(state_get "incident_id")
  resolved=$(state_get "resolved")
  if [[ "$resolved" != "True" ]] && [[ -n "$active" ]]; then
    log_warn "An incident is already active: $active"
    log_warn "Restore it first: ./restore.sh --yes"
    log_warn "Or check status: ./status.sh"
    exit 1
  fi
fi

print_mode

# Select scenario
SELECTED=$(select_scenario)
log_info "Selected incident: $SELECTED"
echo ""

# Source scenario
SCENARIO_FILE="${SCENARIOS_DIR}/${SELECTED}.sh"
source "$SCENARIO_FILE"

# Print briefing (no root cause)
echo "============================================"
echo "  INCIDENT BRIEFING"
echo "============================================"
incident_brief
echo "============================================"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Would inject incident: $SELECTED"
  log_dry "Run with --yes to inject"
  exit 0
fi

# Verify cluster and stack
check_cluster
check_stack_deployed

# Inject
log_info "Injecting incident..."
inject

# Write state
state_write "$SELECTED" "$NAMESPACE" "$DRY_RUN"
log_ok "Incident injected and state saved."
echo ""
echo "Next steps:"
echo "  1. Diagnose the issue using kubectl, helm, logs, events"
echo "  2. Check status:    make incident-status"
echo "  3. Capture evidence: make incident-forensics"
echo "  4. Fix the issue, then: make incident-resolve"
echo "  5. If stuck, restore: make incident-restore YES=1"
