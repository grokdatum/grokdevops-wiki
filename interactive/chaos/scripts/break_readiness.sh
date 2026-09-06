#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEPLOYMENT="grokdevops"
chaos_parse_args "$@"
chaos_check_namespace "$NAMESPACE"
chaos_print_mode

echo "[chaos] Target: readiness probe on deployment/$DEPLOYMENT in $NAMESPACE"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would patch readiness probe path to /nonexistent"
  echo "[DRY-RUN] Current probe:"
  kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "  (no probe or deployment not found)"
  exit 0
fi

# Save current probe path
ORIGINAL_PATH=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null || echo "/health")
echo "[chaos] Original probe path: $ORIGINAL_PATH"
echo "[chaos] Patching to /nonexistent..."

kubectl -n "$NAMESPACE" patch deployment "$DEPLOYMENT" --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/nonexistent"}]'

echo "[chaos] Probe broken. Pods will fail readiness checks."
echo ""
echo "[RESTORE] To restore, run:"
echo "  kubectl -n $NAMESPACE patch deployment $DEPLOYMENT --type=json \\"
echo "    -p='[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"$ORIGINAL_PATH\"}]'"
