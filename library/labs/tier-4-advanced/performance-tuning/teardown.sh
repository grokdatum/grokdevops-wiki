#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-perf"
LAB_DIR="/tmp/lab-perf"

echo "=== Performance Tuning Lab — Teardown ==="

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
fi

rm -rf "${LAB_DIR}" && echo "Removed ${LAB_DIR}" || true

echo "=== Teardown Complete ==="
