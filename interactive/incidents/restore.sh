#!/usr/bin/env bash
# Restore active incident (revert the injected failure)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

incident_parse_args "$@"

echo "============================================"
echo "  INCIDENT RESTORE"
echo "============================================"
echo ""

if ! state_exists; then
  log_info "No active incident to restore."
  exit 0
fi

active=$(state_get "incident_id")
ns=$(state_get "namespace")
resolved=$(state_get "resolved")

if [[ "$resolved" == "True" ]]; then
  log_info "Incident '$active' is already resolved."
  state_clear
  exit 0
fi

NAMESPACE="${ns:-$NAMESPACE}"
log_info "Restoring incident: $active (namespace: $NAMESPACE)"
print_mode

SCENARIO_FILE="${SCENARIOS_DIR}/${active}.sh"
if [[ ! -f "$SCENARIO_FILE" ]]; then
  log_error "Scenario file not found: $SCENARIO_FILE"
  exit 1
fi

source "$SCENARIO_FILE"

if [[ "$DRY_RUN" == "true" ]]; then
  log_dry "Would restore incident: $active"
  log_dry "Run with --yes to restore"
  exit 0
fi

check_cluster

restore
log_ok "Incident '$active' restored."
state_clear
