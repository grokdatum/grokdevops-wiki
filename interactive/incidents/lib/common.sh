#!/usr/bin/env bash
# Shared helpers for incident simulator
# Reuses conventions from training/interactive/chaos/scripts/lib/common.sh

set -euo pipefail

INCIDENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${INCIDENT_DIR}/state.json"
SCOREBOARD_FILE="${INCIDENT_DIR}/scoreboard.jsonl"
SCENARIOS_DIR="${INCIDENT_DIR}/scenarios"

APPROVED_NAMESPACES="grokdevops monitoring argocd kube-system"
DRY_RUN=true
NAMESPACE="grokdevops"
SEED=""
INCIDENT_ID=""
MINUTES=10

# --- Logging ---
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_ok()    { echo "[OK]    $*"; }
log_dry()   { echo "[DRY-RUN] $*"; }
log_live()  { echo "[LIVE]  $*"; }

# --- Help and argument-error contract (mirrors chaos_usage/chaos_arg_error
# in training/interactive/chaos/scripts/lib/common.sh) ---
incident_usage() {
  local command="${0##*/}"

  case "$command" in
    incident.sh)
      echo "Usage: $command [--dry-run|--yes] [--namespace NS] [--seed N] [--incident ID]"
      echo "Select and inject a random (or specific) incident for training."
      ;;
    challenge.sh)
      echo "Usage: $command --yes [--minutes N] [--incident ID] [--namespace NS]"
      echo "Time-boxed incident response training: inject an incident and start a timer."
      ;;
    forensics.sh)
      echo "Usage: $command [--namespace NS]"
      echo "Collect a forensics evidence bundle for the active incident."
      ;;
    restore.sh)
      echo "Usage: $command [--dry-run|--yes] [--namespace NS]"
      echo "Restore the active incident (revert the injected failure)."
      ;;
    resolve.sh)
      echo "Usage: $command"
      echo "Mark the active incident as resolved and record it to the scoreboard."
      ;;
    status.sh)
      echo "Usage: $command"
      echo "Show the current incident status."
      ;;
    selftest.sh)
      echo "Usage: $command"
      echo "Run the incident simulator's offline smoke test (no cluster required)."
      ;;
    *)
      echo "Usage: $command [options]"
      echo "Run one phase of the incident simulator."
      ;;
  esac

  case "$command" in
    incident.sh|challenge.sh|forensics.sh|restore.sh)
      cat <<'EOF'

Options:
  --dry-run          Preview only (default; incident.sh/restore.sh).
  --yes              Execute (inject/restore) instead of previewing.
  --namespace NS     Target namespace (default: grokdevops).
  --seed N           Deterministic scenario selection (incident.sh only).
  --incident ID      Select a specific scenario instead of a random one.
  --minutes N        Challenge time limit (challenge.sh only; default: 10).
  -h, --help         Show this help and exit.
EOF
      ;;
    *)
      cat <<'EOF'

Options:
  -h, --help  Show this help and exit.

This command accepts no positional arguments.
EOF
      ;;
  esac
}

incident_arg_error() {
  printf '%s: error: %s\n' "${0##*/}" "$1" >&2
  printf "Try '%s --help' for usage.\n" "${0##*/}" >&2
  exit 2
}

# --- Argument parsing (incident.sh, challenge.sh, forensics.sh, restore.sh) ---
incident_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)     incident_usage; exit 0 ;;
      --dry-run)     DRY_RUN=true; shift ;;
      --yes)         DRY_RUN=false; shift ;;
      --namespace)
        if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
          incident_arg_error "option --namespace requires a value"
        fi
        NAMESPACE="$2"; shift 2 ;;
      --namespace=) incident_arg_error "option --namespace requires a value" ;;
      --namespace=*) NAMESPACE="${1#*=}"; shift ;;
      --seed)
        if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
          incident_arg_error "option --seed requires a value"
        fi
        SEED="$2"; shift 2 ;;
      --seed=) incident_arg_error "option --seed requires a value" ;;
      --seed=*) SEED="${1#*=}"; shift ;;
      --incident)
        if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
          incident_arg_error "option --incident requires a value"
        fi
        INCIDENT_ID="$2"; shift 2 ;;
      --incident=) incident_arg_error "option --incident requires a value" ;;
      --incident=*) INCIDENT_ID="${1#*=}"; shift ;;
      --minutes)
        if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
          incident_arg_error "option --minutes requires a value"
        fi
        MINUTES="$2"; shift 2 ;;
      --minutes=) incident_arg_error "option --minutes requires a value" ;;
      --minutes=*) MINUTES="${1#*=}"; shift ;;
      -*) incident_arg_error "unknown option: $1" ;;
      *) incident_arg_error "unexpected argument: $1" ;;
    esac
  done
}

# --- Argument parsing (resolve.sh, status.sh, selftest.sh: no positional
# options besides -h/--help) ---
incident_parse_no_args() {
  if (( $# == 0 )); then
    return 0
  fi
  if (( $# == 1 )) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    incident_usage
    exit 0
  fi
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    incident_arg_error "the help option does not accept arguments"
  elif [[ "$1" == -* ]]; then
    incident_arg_error "unknown option: $1"
  else
    incident_arg_error "unexpected argument: $1"
  fi
}

# --- Safety checks ---
check_namespace_approved() {
  local ns="$1"
  for approved in $APPROVED_NAMESPACES; do
    [[ "$ns" == "$approved" ]] && return 0
  done
  log_error "Namespace '$ns' is not approved. Allowed: $APPROVED_NAMESPACES"
  exit 1
}

check_cluster() {
  if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to cluster. Check your kubeconfig."
    exit 1
  fi
}

check_stack_deployed() {
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_error "Training stack not deployed. Run: make deploy-all"
    exit 1
  fi
}

print_mode() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Preview mode. Pass --yes to execute."
  else
    log_live "Executing against namespace: $NAMESPACE"
  fi
}

# --- Scenario listing ---
list_scenarios() {
  for f in "${SCENARIOS_DIR}"/*.sh; do
    [[ -f "$f" ]] && basename "$f" .sh
  done
}

# --- Scenario selection ---
select_scenario() {
  local scenarios=()
  while IFS= read -r s; do
    scenarios+=("$s")
  done < <(list_scenarios)

  if [[ ${#scenarios[@]} -eq 0 ]]; then
    log_error "No scenarios found in ${SCENARIOS_DIR}"
    exit 1
  fi

  if [[ -n "$INCIDENT_ID" ]]; then
    if [[ -f "${SCENARIOS_DIR}/${INCIDENT_ID}.sh" ]]; then
      echo "$INCIDENT_ID"
      return
    else
      log_error "Scenario not found: $INCIDENT_ID"
      log_error "Available: ${scenarios[*]}"
      exit 1
    fi
  fi

  local count=${#scenarios[@]}
  local idx
  if [[ -n "$SEED" ]]; then
    idx=$(( SEED % count ))
  else
    idx=$(( RANDOM % count ))
  fi
  echo "${scenarios[$idx]}"
}

# --- State management ---
state_exists() {
  [[ -f "$STATE_FILE" ]]
}

state_read() {
  if state_exists; then
    cat "$STATE_FILE"
  else
    echo "{}"
  fi
}

state_get() {
  local key="$1"
  if state_exists; then
    python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('$key',''))" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

state_write() {
  local incident_id="$1"
  local ns="$2"
  local dry_run="$3"
  local extra="${4:-}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 -c "
import json, sys
state = {
    'incident_id': '$incident_id',
    'namespace': '$ns',
    'started_at': '$now',
    'dry_run': $( [[ "$dry_run" == "true" ]] && echo "True" || echo "False" ),
    'resolved': False
}
if '''$extra''':
    state['extra'] = '''$extra'''
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
print(json.dumps(state, indent=2))
"
}

state_clear() {
  rm -f "$STATE_FILE"
}

# --- Scoreboard ---
scoreboard_record() {
  local incident_id="$1"
  local started_at="$2"
  local resolved_at="$3"
  local duration_seconds="$4"
  local notes="${5:-}"
  python3 -c "
import json
entry = {
    'incident_id': '$incident_id',
    'started_at': '$started_at',
    'resolved_at': '$resolved_at',
    'duration_seconds': $duration_seconds,
    'notes': '$notes'
}
with open('$SCOREBOARD_FILE', 'a') as f:
    f.write(json.dumps(entry) + '\n')
"
}

# --- Kubectl wrappers ---
kube_get() {
  kubectl get "$@" -n "$NAMESPACE" 2>/dev/null
}

kube_describe() {
  kubectl describe "$@" -n "$NAMESPACE" 2>/dev/null
}

kube_patch() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would run: kubectl patch $* -n $NAMESPACE"
  else
    kubectl patch "$@" -n "$NAMESPACE"
  fi
}

kube_apply() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would run: kubectl apply $* -n $NAMESPACE"
  else
    kubectl apply "$@" -n "$NAMESPACE"
  fi
}

kube_delete() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_dry "Would run: kubectl delete $* -n $NAMESPACE"
  else
    kubectl delete "$@" -n "$NAMESPACE" --ignore-not-found
  fi
}
