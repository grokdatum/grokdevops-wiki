#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[break] Saving current ServiceMonitor..."
kubectl get servicemonitor grokdevops -n "$NAMESPACE" -o yaml > /tmp/servicemonitor-backup.yaml 2>/dev/null || true
echo "[break] Patching ServiceMonitor with wrong selector..."
kubectl patch servicemonitor grokdevops -n "$NAMESPACE" --type=json \
  -p='[{"op":"replace","path":"/spec/selector/matchLabels/app.kubernetes.io~1name","value":"wrong-app-name"}]'
echo "[break] ServiceMonitor now selects 'wrong-app-name' instead of 'grokdevops'."
echo "[break] Check Prometheus targets (wait ~60s for scrape cycle):"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "  # Open http://localhost:9090/targets — grokdevops target should be gone"
