#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-incident-sim"
LAB_DIR="/tmp/lab-incident-sim"

echo "=== Incident Simulation Lab — Teardown ==="

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
fi

rm -rf "${LAB_DIR}" && echo "Removed ${LAB_DIR}" || true

echo "=== Teardown Complete ==="
