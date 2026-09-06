#!/usr/bin/env bash
# trigger.sh — Create an active incident for investigation practice.
#
# Usage:
#   ./trigger.sh <incident_id> [description]
#   ./trigger.sh --list          # show available incident IDs
#   ./trigger.sh --clear         # remove active incident state
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

KNOWN_INCIDENTS=(
  service-down crashloopbackoff probe-failure imagepullbackoff
  oomkilled hpa-not-scaling dns-resolution networkpolicy-block
  helm-upgrade-failed prometheus-target-down loki-no-logs latency-spike
)

show_list() {
  print_header "Available Incident IDs"
  for id in "${KNOWN_INCIDENTS[@]}"; do
    local resolved
    resolved=$(resolve_playbook "$id")
    if [[ -f "$resolved" ]]; then
      printf "  ${GREEN}%-28s${RST} (runbook: %s)\n" "$id" "$(basename "$resolved" .md)"
    else
      printf "  ${DIM}%-28s${RST} (no runbook)\n" "$id"
    fi
  done
  echo ""
}

trigger_usage() {
  local command="${0##*/}"
  echo "Usage: $command <incident_id> [description]"
  echo "       $command --list"
  echo "       $command --clear"
  echo "Create (or list, or clear) the active incident for investigation practice."
  echo ""
  echo "Options:"
  echo "  -l, --list   Show available incident IDs and exit."
  echo "  -c, --clear  Remove the active incident state and exit."
  echo "  -h, --help   Show this help and exit."
}

trigger_arg_error() {
  printf '%s: error: %s\n' "${0##*/}" "$1" >&2
  printf "Try '%s --help' for usage.\n" "${0##*/}" >&2
  exit 2
}

if [[ $# -eq 1 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
  trigger_usage
  exit 0
fi

if [[ $# -eq 0 ]]; then
  trigger_usage
  exit 1
fi

case "$1" in
  --list|-l) show_list; exit 0 ;;
  --clear|-c)
    if state_exists; then
      local_id=$(state_get incident_id)
      state_remove
      print_ok "Cleared incident: $local_id"
    else
      echo "No active incident to clear."
    fi
    exit 0
    ;;
  -h|--help) trigger_arg_error "the help option does not accept arguments" ;;
  -*) trigger_arg_error "unknown option: $1" ;;
esac

if [[ $# -gt 2 ]]; then
  trigger_arg_error "too many arguments (expected <incident_id> [description])"
fi

INCIDENT_ID="$1"
DESCRIPTION="${2:-Incident: $INCIDENT_ID}"

if state_exists; then
  existing=$(state_get incident_id)
  print_warn "An incident is already active: $existing"
  echo "Clear it first: ${0##*/} --clear"
  exit 1
fi

state_create "$INCIDENT_ID" "manual" "$DESCRIPTION"
print_ok "Incident triggered: $INCIDENT_ID"
echo "Next: make investigate"
