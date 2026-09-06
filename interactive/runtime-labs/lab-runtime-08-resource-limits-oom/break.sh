#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[break] Patching deployment with extremely low memory limit (4Mi)..."
kubectl patch deployment grokdevops -n "$NAMESPACE" --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"4Mi"},{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"4Mi"}]'
echo "[break] Pods will restart and likely OOMKill."
echo "[break] Watch: kubectl get pods -n $NAMESPACE -w"
echo "[break] Check: kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=grokdevops | grep -A3 'Last State'"
