#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-monitoring"

echo "=== Monitoring Stack Lab — Teardown ==="

kubectl delete clusterrole lab-prometheus --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrolebinding lab-prometheus --ignore-not-found=true 2>/dev/null || true

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
fi

echo "=== Teardown Complete ==="
