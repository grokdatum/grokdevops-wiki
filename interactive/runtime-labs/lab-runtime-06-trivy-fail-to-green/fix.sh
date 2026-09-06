#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[fix] Building with the repo's actual Dockerfile (secure base)..."
docker build -t grokdevops:test . 2>&1
echo "[fix] Scanning fixed image..."
trivy image --severity CRITICAL,HIGH grokdevops:test 2>/dev/null || {
  echo "[fix] Trivy not installed. The repo Dockerfile uses a current slim base."
}
echo "[fix] Compare vulnerability counts between the two images."
