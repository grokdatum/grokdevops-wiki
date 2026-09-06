#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[fix] Rolling back to previous Helm revision..."
helm rollback grokdevops 0 -n "$NAMESPACE" --wait --timeout=120s
echo "[fix] Rollback complete."
echo "[fix] Check: kubectl get pods -n $NAMESPACE"
