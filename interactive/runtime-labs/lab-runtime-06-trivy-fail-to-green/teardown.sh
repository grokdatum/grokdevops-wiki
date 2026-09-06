#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[teardown] Removing test images..."
docker rmi grokdevops-vuln-test:latest 2>/dev/null || true
docker rmi grokdevops:test 2>/dev/null || true
rm -f "$SCRIPT_DIR/assets/Dockerfile.vulnerable"
echo "[teardown] Done."
