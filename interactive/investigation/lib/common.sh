#!/usr/bin/env bash
# Shared helpers for the investigation engine.
# Sourced by investigate.sh, hints.sh, explain.sh, selftest.sh.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
INVESTIGATION_DIR="$REPO_ROOT/training/interactive/investigation"
STATE_DIR="$REPO_ROOT/training/interactive/investigation/.state"
RUNBOOKS_DIR="$REPO_ROOT/training/library/runbooks"
# Legacy alias — investigate.sh now reads runbooks directly.
PLAYBOOKS_DIR="$RUNBOOKS_DIR"
HINTS_DIR="$INVESTIGATION_DIR/hints"
JOURNAL_DIR="$INVESTIGATION_DIR/journal"
MAP_FILE="$INVESTIGATION_DIR/map.tsv"

# ── Help / argument-error contract ──────────────────────────────
# investigate.sh, hints.sh, explain.sh, and selftest.sh take no
# positional arguments (they act on the active incident / env vars).
# Call investigation_parse_no_args "$@" before any state read/write.
investigation_usage() {
  local command="${0##*/}"

  case "$command" in
    investigate.sh)
      echo "Usage: $command"
      echo "Print a step-by-step investigation plan for the active incident."
      ;;
    hints.sh)
      echo "Usage: $command"
      echo "Show a progressive hint for the active incident."
      echo "Environment: HINT selects the level, 1-4 (default: 1)."
      ;;
    explain.sh)
      echo "Usage: $command"
      echo "Record findings for the active incident to a journal entry."
      echo "Environment: INTERACTIVE=1 prompts for each field instead of"
      echo "writing a fill-in-the-blank template."
      ;;
    selftest.sh)
      echo "Usage: $command"
      echo "Verify the investigation engine scripts run without errors."
      echo "Non-destructive: creates a mock incident state, then cleans up."
      ;;
    *)
      echo "Usage: $command"
      echo "Run one phase of the investigation engine."
      ;;
  esac

  cat <<'EOF'

Options:
  -h, --help  Show this help and exit.

This command accepts no positional arguments.
EOF
}

investigation_arg_error() {
  printf '%s: error: %s\n' "${0##*/}" "$1" >&2
  printf "Try '%s --help' for usage.\n" "${0##*/}" >&2
  exit 2
}

investigation_parse_no_args() {
  if (( $# == 0 )); then
    return 0
  fi
  if (( $# == 1 )) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    investigation_usage
    exit 0
  fi
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    investigation_arg_error "the help option does not accept arguments"
  elif [[ "$1" == -* ]]; then
    investigation_arg_error "unknown option: $1"
  else
    investigation_arg_error "unexpected argument: $1"
  fi
}

# Namespace (default)
NAMESPACE="${NAMESPACE:-grokdevops}"

# ── Colours (respects NO_COLOR) ──────────────────────────────────
if [[ -z "${NO_COLOR:-}" ]]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RED='\033[31m'
  CYAN='\033[36m'
  RST='\033[0m'
else
  BOLD='' DIM='' GREEN='' YELLOW='' RED='' CYAN='' RST=''
fi

# ── State management ────────────────────────────────────────────
# State file format: simple key=value, one per line.
# Keys: incident_id, started_at, chaos_script, description

state_file() { echo "$STATE_DIR/active"; }

state_exists() { [[ -f "$(state_file)" ]]; }

state_get() {
  local key="$1"
  grep "^${key}=" "$(state_file)" 2>/dev/null | head -1 | cut -d= -f2-
}

state_create() {
  mkdir -p "$STATE_DIR"
  cat > "$(state_file)" <<EOF
incident_id=$1
started_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
chaos_script=${2:-manual}
description=${3:-Incident triggered}
EOF
}

state_remove() { rm -f "$(state_file)"; }

# ── Incident detection ──────────────────────────────────────────
# Reads the active incident ID. Returns 1 if none.
get_active_incident() {
  if state_exists; then
    state_get incident_id
    return 0
  fi
  return 1
}

require_active_incident() {
  if ! state_exists; then
    printf "${RED}No active incident.${RST}\n"
    echo "Start one with:"
    echo "  make incident YES=1"
    echo "  (or: training/interactive/investigation/trigger.sh <incident_id>)"
    return 1
  fi
}

# ── Runbook lookup ──────────────────────────────────────────────
resolve_playbook() {
  local id="$1"
  # Try exact match first (e.g. crashloopbackoff, oomkilled)
  local rb="$RUNBOOKS_DIR/${id}.md"
  if [[ -f "$rb" ]]; then
    echo "$rb"
    return
  fi
  # Map hyphenated incident IDs to underscored runbook names
  local underscore_id="${id//-/_}"
  rb="$RUNBOOKS_DIR/${underscore_id}.md"
  if [[ -f "$rb" ]]; then
    echo "$rb"
    return
  fi
  # Fallback: crashloopbackoff is the most general runbook
  echo "$RUNBOOKS_DIR/crashloopbackoff.md"
}

# ── Map lookup ──────────────────────────────────────────────────
# Returns the map.tsv row for a given incident_id (tab-separated).
map_lookup() {
  local id="$1"
  grep "^${id}	" "$MAP_FILE" 2>/dev/null | head -1
}

# ── Pretty printing helpers ─────────────────────────────────────
print_header() { printf "\n${BOLD}${CYAN}=== %s ===${RST}\n\n" "$1"; }
print_step()   { printf "${BOLD}[Step %s]${RST} %s\n" "$1" "$2"; }
print_cmd()    { printf "  ${GREEN}\$ %s${RST}\n" "$1"; }
print_expect() { printf "  ${DIM}Look for: %s${RST}\n" "$1"; }
print_warn()   { printf "${YELLOW}%s${RST}\n" "$1"; }
print_ok()     { printf "${GREEN}%s${RST}\n" "$1"; }
print_err()    { printf "${RED}%s${RST}\n" "$1"; }
