#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-rbac"

echo "=== RBAC & Security Lab — Teardown ==="

# Remove cluster-scoped RBAC resources
kubectl delete clusterrole lab-ops-role lab-auditor-role --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrolebinding lab-ops-binding lab-auditor-binding --ignore-not-found=true 2>/dev/null || true
echo "Removed cluster-scoped RBAC resources."

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
fi

echo "=== Teardown Complete ==="
