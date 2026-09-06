#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[verify] Checking for OOMKilled pods..."
OOM_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grokdevops -o jsonpath='{range .items[*]}{.status.containerStatuses[*].lastState.terminated.reason}{"\n"}{end}' 2>/dev/null | grep -c OOMKilled || echo "0")
READY=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$READY" -ge 1 ]] && [[ "$OOM_COUNT" == "0" ]]; then
  echo "[verify] PASS: $READY replica(s) ready, no recent OOMKills"
else
  echo "[verify] FAIL: ready=$READY, recent OOMKills=$OOM_COUNT"
  exit 1
fi
