#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[fix] Restoring reasonable memory limits..."
kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"256Mi"},{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"128Mi"}]'
echo "[fix] Waiting for rollout..."
kubectl rollout status deployment/grokdevops -n "$NAMESPACE" --timeout=120s
echo "[fix] Done."
