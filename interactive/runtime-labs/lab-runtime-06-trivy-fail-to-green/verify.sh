#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
echo "[verify] Scanning repo image for CRITICAL/HIGH vulnerabilities..."
RESULT=$(trivy image --severity CRITICAL,HIGH --exit-code 1 grokdevops:test 2>&1) && {
  echo "[verify] PASS: No CRITICAL/HIGH vulnerabilities found"
} || {
  echo "$RESULT"
  echo "[verify] FAIL: Vulnerabilities found (review output above)"
  exit 1
}
