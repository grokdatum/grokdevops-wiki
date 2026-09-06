#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ACTION="apply"
if [[ $# -gt 0 ]]; then
  case "$1" in
    apply|remove) ACTION="$1"; shift ;;
    -h|--help) chaos_usage; exit 0 ;;
    -*) ;;
    *) chaos_arg_error "unexpected action: $1" ;;
  esac
fi
chaos_parse_args "$@"
chaos_check_namespace "$NAMESPACE"
chaos_print_mode

POLICY_NAME="chaos-deny-all"

if [[ "$ACTION" == "apply" ]]; then
  echo "[chaos] Will apply restrictive NetworkPolicy '$POLICY_NAME' in $NAMESPACE"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would block all ingress/egress for pods with label app.kubernetes.io/name=grokdevops"
    exit 0
  fi
  cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${POLICY_NAME}
  labels:
    chaos: "true"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: grokdevops
  policyTypes:
  - Ingress
  - Egress
EOF
  echo "[chaos] NetworkPolicy applied. All traffic to/from grokdevops pods is blocked."
  echo "[chaos] Test: kubectl exec -n $NAMESPACE deploy/grokdevops -- wget -qO- --timeout=3 http://grokdevops/health"
  echo ""
  echo "[RESTORE] ./toggle_networkpolicy.sh remove --yes --namespace $NAMESPACE"

elif [[ "$ACTION" == "remove" ]]; then
  echo "[chaos] Will remove NetworkPolicy '$POLICY_NAME' from $NAMESPACE"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would delete NetworkPolicy $POLICY_NAME"
    exit 0
  fi
  kubectl delete networkpolicy "$POLICY_NAME" -n "$NAMESPACE" --ignore-not-found=true
  echo "[chaos] NetworkPolicy removed. Traffic restored."
else
  chaos_arg_error "unexpected action: $ACTION"
fi
