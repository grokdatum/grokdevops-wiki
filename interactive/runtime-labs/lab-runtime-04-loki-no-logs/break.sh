#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

MONITORING_NS="${MONITORING_NS:-monitoring}"
echo "[break] Saving promtail DaemonSet replica state..."
echo "[break] Patching promtail DaemonSet with a nodeSelector that matches nothing..."
kubectl patch daemonset -n "$MONITORING_NS" -l app.kubernetes.io/name=promtail \
  --type=json -p='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"non-existent-label":"true"}}]' 2>/dev/null || \
  kubectl patch daemonset promtail -n "$MONITORING_NS" \
  --type=json -p='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"non-existent-label":"true"}}]'
echo "[break] Promtail pods will terminate (no node matches selector)."
echo "[break] Wait ~30s then check Grafana Loki — new logs should stop appearing."
echo "  kubectl port-forward -n $MONITORING_NS svc/kube-prometheus-stack-grafana 3000:80"
echo "  # Explore → Loki → {namespace=\"grokdevops\"}"
