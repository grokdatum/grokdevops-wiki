#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[verify] Checking for drift indicators..."
REPLICAS=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
HAS_ROGUE=$(kubectl get deployment grokdevops -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="ROGUE_VAR")].value}' 2>/dev/null || echo "")
PASS=true
if [[ "$REPLICAS" != "1" ]] && [[ "$REPLICAS" != "2" ]]; then
  echo "[verify] WARN: Replicas=$REPLICAS (expected 1 or 2 from values-dev)"
  PASS=false
fi
if [[ -n "$HAS_ROGUE" ]]; then
  echo "[verify] FAIL: ROGUE_VAR still present ('$HAS_ROGUE')"
  PASS=false
fi
if [[ "$PASS" == "true" ]]; then
  echo "[verify] PASS: No drift detected. Deployment matches Helm state."
else
  exit 1
fi
