#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[verify] Checking deployment status..."
kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=60s
READY=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$READY" -ge 1 ]]; then
  echo "[verify] PASS: $READY replica(s) ready after rollback"
else
  echo "[verify] FAIL: No ready replicas"
  exit 1
fi
