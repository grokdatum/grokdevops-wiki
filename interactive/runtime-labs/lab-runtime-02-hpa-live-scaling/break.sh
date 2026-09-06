#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[load] Ensuring HPA exists..."
kubectl get hpa grokdevops -n "$NAMESPACE" 2>/dev/null || \
  kubectl autoscale deployment grokdevops -n "$NAMESPACE" --cpu-percent=50 --min=1 --max=5
echo "[load] Starting load generator pod..."
kubectl run load-generator -n "$NAMESPACE" --image=busybox:1.36 --restart=Never --rm -i --timeout=300s -- \
  /bin/sh -c "while true; do wget -q -O- http://grokdevops/health >/dev/null 2>&1; done" &
LOAD_PID=$!
echo "[load] Load generator running (PID: $LOAD_PID). Monitor with:"
echo "  kubectl get hpa -n $NAMESPACE -w"
echo "  kubectl top pods -n $NAMESPACE"
echo "[load] Press Ctrl+C or run teardown.sh to stop."
wait $LOAD_PID 2>/dev/null || true
