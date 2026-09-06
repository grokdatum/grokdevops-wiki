#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEPLOYMENT="grokdevops"
chaos_parse_args "$@"
chaos_check_namespace "$NAMESPACE"
chaos_print_mode

echo "[chaos] Target: deployment/$DEPLOYMENT in $NAMESPACE"

CURRENT_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would scale deployment/$DEPLOYMENT from $CURRENT_REPLICAS to 0"
  echo "[DRY-RUN] Would wait 10s then restore to $CURRENT_REPLICAS"
  exit 0
fi

echo "[chaos] Current replicas: $CURRENT_REPLICAS"
echo "[chaos] Scaling to 0..."
kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas=0
echo "[chaos] Deployment scaled to 0. Service is down."
echo "[chaos] Waiting 10s before restoring..."
sleep 10

echo "[chaos] Restoring to $CURRENT_REPLICAS replicas..."
kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas="$CURRENT_REPLICAS"
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s
echo "[chaos] Restored. Deployment is back to $CURRENT_REPLICAS replicas."
