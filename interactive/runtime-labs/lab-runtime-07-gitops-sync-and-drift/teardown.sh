#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[teardown] Ensuring clean Helm state..."
helm upgrade grokdevops devops/helm/grokdevops -n "$NAMESPACE" -f devops/helm/values-dev.yaml --wait --timeout=120s 2>/dev/null || true
echo "[teardown] Done."
