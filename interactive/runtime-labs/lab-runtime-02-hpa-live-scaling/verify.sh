#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[verify] Checking HPA status..."
kubectl get hpa grokdevops -n "$NAMESPACE"
echo ""
REPLICAS=$(kubectl get hpa grokdevops -n "$NAMESPACE" -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "0")
echo "[verify] Current replicas: $REPLICAS"
if [[ "$REPLICAS" -gt 1 ]]; then
  echo "[verify] PASS: HPA has scaled up to $REPLICAS replicas"
else
  echo "[verify] INFO: HPA at $REPLICAS replica(s). If load is running, wait for metrics to propagate (~60s)."
fi
