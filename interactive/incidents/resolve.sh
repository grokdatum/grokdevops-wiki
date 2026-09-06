#!/usr/bin/env bash
# Mark the active incident as resolved and record to scoreboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

incident_parse_no_args "$@"

echo "============================================"
echo "  INCIDENT RESOLVE"
echo "============================================"
echo ""

if ! state_exists; then
  log_info "No active incident to resolve."
  exit 0
fi

active=$(state_get "incident_id")
started=$(state_get "started_at")
ns=$(state_get "namespace")
resolved=$(state_get "resolved")

if [[ "$resolved" == "True" ]]; then
  log_info "Incident '$active' is already resolved."
  state_clear
  exit 0
fi

NAMESPACE="${ns:-grokdevops}"

# Optionally verify the fix
SCENARIO_FILE="${SCENARIOS_DIR}/${active}.sh"
if [[ -f "$SCENARIO_FILE" ]]; then
  source "$SCENARIO_FILE"
  if type verify &>/dev/null; then
    log_info "Verifying fix..."
    if verify "fixed"; then
      log_ok "Verification passed - incident is fixed."
    else
      log_warn "Verification failed - incident may not be fully resolved."
      log_warn "Continue anyway? The scoreboard will record this attempt."
    fi
  fi
fi

# Record
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
now_epoch=$(date -u +%s)
start_epoch=$(date -u -d "$started" +%s 2>/dev/null || echo "$now_epoch")
duration=$(( now_epoch - start_epoch ))
mins=$(( duration / 60 ))
secs=$(( duration % 60 ))

scoreboard_record "$active" "$started" "$now" "$duration" ""

log_ok "Incident '$active' resolved in ${mins}m ${secs}s"
state_clear

echo ""
echo "Scoreboard updated: ${SCOREBOARD_FILE}"
echo "View with: make scoreboard"
