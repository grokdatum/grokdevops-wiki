#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[fix] Stopping load generator..."
kubectl delete pod load-generator -n "$NAMESPACE" --ignore-not-found=true
echo "[fix] HPA will scale down after cooldown period (~5 min)."
echo "[fix] Monitor: kubectl get hpa -n $NAMESPACE -w"
