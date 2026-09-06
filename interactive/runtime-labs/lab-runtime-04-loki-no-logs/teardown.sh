#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

MONITORING_NS="${MONITORING_NS:-monitoring}"
echo "[teardown] Restoring promtail via Helm..."
helm upgrade promtail grafana/promtail -n "$MONITORING_NS" -f devops/observability/values/values-promtail.yaml --wait --timeout=120s 2>/dev/null || true
echo "[teardown] Done."
