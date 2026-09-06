#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[verify] Checking ServiceMonitor selector..."
SELECTOR=$(kubectl get servicemonitor grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.selector.matchLabels.app\.kubernetes\.io/name}' 2>/dev/null)
if [[ "$SELECTOR" == "grokdevops" ]]; then
  echo "[verify] PASS: ServiceMonitor selector is correct ($SELECTOR)"
else
  echo "[verify] FAIL: ServiceMonitor selector is '$SELECTOR' (expected 'grokdevops')"
  exit 1
fi
echo "[verify] Check Prometheus targets UI to confirm target is UP."
