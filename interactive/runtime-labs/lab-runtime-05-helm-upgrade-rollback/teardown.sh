#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
NAMESPACE="${NAMESPACE:-grokdevops}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[teardown] Ensuring clean Helm state..."
helm upgrade grokdevops devops/helm/grokdevops -n "$NAMESPACE" -f devops/helm/values-dev.yaml --wait --timeout=120s 2>/dev/null || true
rm -f "$SCRIPT_DIR/assets/bad-values.yaml"
echo "[teardown] Done."
