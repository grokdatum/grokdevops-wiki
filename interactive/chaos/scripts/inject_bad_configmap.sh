#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEPLOYMENT="grokdevops"
CM_NAME="chaos-bad-config"
chaos_parse_args "$@"
chaos_check_namespace "$NAMESPACE"
chaos_print_mode

echo "[chaos] Will inject a bad ConfigMap and mount it in deployment/$DEPLOYMENT"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would create ConfigMap '$CM_NAME' with bad data"
  echo "[DRY-RUN] Would add env vars from ConfigMap to the deployment"
  echo "[DRY-RUN] Would restore by removing the env ref and deleting the ConfigMap"
  exit 0
fi

echo "[chaos] Creating bad ConfigMap..."
kubectl create configmap "$CM_NAME" -n "$NAMESPACE" \
  --from-literal=APP_PORT=invalid-not-a-number \
  --from-literal=APP_DEBUG=CHAOS_INJECTED \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[chaos] Injecting ConfigMap as env source into deployment..."
kubectl set env deployment/"$DEPLOYMENT" -n "$NAMESPACE" --from=configmap/"$CM_NAME"

echo "[chaos] Bad config injected. App may crash or behave unexpectedly."
echo "[chaos] Check: kubectl get pods -n $NAMESPACE -w"
echo ""
echo "[RESTORE] To restore:"
echo "  kubectl set env deployment/$DEPLOYMENT -n $NAMESPACE --from=configmap/$CM_NAME-"
echo "  kubectl delete configmap $CM_NAME -n $NAMESPACE"
echo "  # Or: helm upgrade grokdevops devops/helm/grokdevops -n $NAMESPACE -f devops/helm/values-dev.yaml"
