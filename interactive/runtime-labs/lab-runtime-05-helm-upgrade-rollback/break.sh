#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
NAMESPACE="${NAMESPACE:-grokdevops}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[break] Creating bad values override..."
mkdir -p "$SCRIPT_DIR/assets"
cat > "$SCRIPT_DIR/assets/bad-values.yaml" << 'EOF'
image:
  tag: "nonexistent-tag-99.99.99"
EOF
echo "[break] Recording current Helm revision..."
helm history grokdevops -n "$NAMESPACE" --max 1
echo "[break] Upgrading with bad image tag..."
helm upgrade grokdevops devops/helm/grokdevops -n "$NAMESPACE" \
  -f devops/helm/values-dev.yaml \
  -f "$SCRIPT_DIR/assets/bad-values.yaml" \
  --wait --timeout=60s 2>&1 || true
echo "[break] Upgrade likely failed or pods are in ImagePullBackOff."
echo "[break] Check: kubectl get pods -n $NAMESPACE"
