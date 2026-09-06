#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[fix] Restoring correct readiness probe path..."
kubectl -n "$NAMESPACE" patch deployment grokdevops --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/health"}]'
echo "[fix] Waiting for rollout to complete..."
kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s
echo "[fix] Done. Deployment should be healthy."
