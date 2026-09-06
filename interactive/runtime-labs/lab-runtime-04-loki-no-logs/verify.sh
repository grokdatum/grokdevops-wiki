#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

MONITORING_NS="${MONITORING_NS:-monitoring}"
echo "[verify] Checking promtail pods..."
DESIRED=$(kubectl get daemonset promtail -n "$MONITORING_NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
READY=$(kubectl get daemonset promtail -n "$MONITORING_NS" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
if [[ "$READY" -ge 1 ]] && [[ "$READY" == "$DESIRED" ]]; then
  echo "[verify] PASS: Promtail $READY/$DESIRED pods ready"
else
  echo "[verify] FAIL: Promtail $READY/$DESIRED pods ready"
  exit 1
fi
