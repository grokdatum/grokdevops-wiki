#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[fix] Reconciling drift via Helm upgrade (simulating GitOps sync)..."
helm upgrade grokdevops devops/helm/grokdevops -n "$NAMESPACE" \
  -f devops/helm/values-dev.yaml --wait --timeout=120s
echo "[fix] Drift reconciled. Deployment matches declared state."
