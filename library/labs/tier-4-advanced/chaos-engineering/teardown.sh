#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-chaos"
LAB_DIR="/tmp/lab-chaos"

echo "=== Chaos Engineering Lab — Teardown ==="

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
fi

if [[ -d "${LAB_DIR}" ]]; then
    echo "Removing ${LAB_DIR}..."
    rm -rf "${LAB_DIR}"
fi

echo "=== Teardown Complete ==="
