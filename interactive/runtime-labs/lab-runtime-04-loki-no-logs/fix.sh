#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

MONITORING_NS="${MONITORING_NS:-monitoring}"
echo "[fix] Removing broken nodeSelector from promtail DaemonSet..."
kubectl patch daemonset -n "$MONITORING_NS" -l app.kubernetes.io/name=promtail \
  --type=json -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]' 2>/dev/null || \
  kubectl patch daemonset promtail -n "$MONITORING_NS" \
  --type=json -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
echo "[fix] Promtail pods will restart on all nodes."
echo "[fix] Wait ~30s for logs to start flowing again."
