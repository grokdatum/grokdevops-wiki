#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="/tmp/lab-multicluster"

echo "=== Multi-Cluster Lab — Teardown ==="

for ns in lab-cluster-primary lab-cluster-secondary lab-cluster-router; do
    if kubectl get namespace "${ns}" > /dev/null 2>&1; then
        echo "Deleting namespace ${ns}..."
        kubectl delete namespace "${ns}" --wait=false
    fi
done

rm -rf "${LAB_DIR}" && echo "Removed ${LAB_DIR}" || true

echo "=== Teardown Complete ==="
