#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[break] Patching deployment to use broken readiness probe..."
kubectl -n "$NAMESPACE" patch deployment grokdevops --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/nonexistent"}]'
echo "[break] Waiting for rollout to stall..."
sleep 5
echo "[break] Check status: kubectl rollout status deployment/grokdevops -n $NAMESPACE --timeout=30s"
echo "[break] Done. The deployment should show pods not becoming ready."
