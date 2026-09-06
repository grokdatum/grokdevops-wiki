#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[verify] Checking deployment readiness..."
READY=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
if [[ "$READY" == "$DESIRED" ]] && [[ "$READY" != "0" ]]; then
  echo "[verify] PASS: $READY/$DESIRED replicas ready"
  exit 0
else
  echo "[verify] FAIL: $READY/$DESIRED replicas ready"
  exit 1
fi
