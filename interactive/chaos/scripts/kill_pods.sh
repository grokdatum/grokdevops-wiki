#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

LABEL="app.kubernetes.io/name=grokdevops"
COUNT="all"

# Parse extra args
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) chaos_usage; exit 0 ;;
    --label)
      if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
        chaos_arg_error "option --label requires a value"
      fi
      LABEL="$2"
      shift 2
      ;;
    --label=) chaos_arg_error "option --label requires a value" ;;
    --label=*) LABEL="${1#*=}"; shift ;;
    --count)
      if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
        chaos_arg_error "option --count requires a value"
      fi
      COUNT="$2"
      shift 2
      ;;
    --count=) chaos_arg_error "option --count requires a value" ;;
    --count=*) COUNT="${1#*=}"; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
chaos_parse_args "${ARGS[@]+"${ARGS[@]}"}"
chaos_check_namespace "$NAMESPACE"
chaos_print_mode

echo "[chaos] Target: pods with label '$LABEL' in namespace '$NAMESPACE'"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would delete:"
  kubectl get pods -n "$NAMESPACE" -l "$LABEL" --no-headers 2>/dev/null || echo "  (no matching pods)"
  exit 0
fi

PODS=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL" -o name --no-headers 2>/dev/null)
if [[ -z "$PODS" ]]; then
  echo "[chaos] No pods found matching label '$LABEL' in namespace '$NAMESPACE'"
  exit 0
fi

if [[ "$COUNT" == "all" ]]; then
  echo "[chaos] Deleting all matching pods..."
  kubectl delete pods -n "$NAMESPACE" -l "$LABEL"
else
  echo "[chaos] Deleting $COUNT pod(s)..."
  echo "$PODS" | head -n "$COUNT" | xargs kubectl delete -n "$NAMESPACE"
fi

echo "[chaos] Pods deleted. Deployment controller will recreate them."
echo "[chaos] Watch: kubectl get pods -n $NAMESPACE -l $LABEL -w"
