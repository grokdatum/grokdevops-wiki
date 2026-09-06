#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-storage"

echo "=== Storage & State Lab — Teardown ==="

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
fi

rm -rf /tmp/lab-storage-backups && echo "Removed backup directory" || true

echo "=== Teardown Complete ==="
