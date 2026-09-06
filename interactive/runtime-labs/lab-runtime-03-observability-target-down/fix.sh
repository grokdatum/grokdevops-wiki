#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[fix] Restoring correct ServiceMonitor selector..."
kubectl patch servicemonitor grokdevops -n "$NAMESPACE" --type=json \
  -p='[{"op":"replace","path":"/spec/selector/matchLabels/app.kubernetes.io~1name","value":"grokdevops"}]'
echo "[fix] ServiceMonitor restored. Wait ~60s for Prometheus to pick up the target."
echo "[fix] Verify: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
