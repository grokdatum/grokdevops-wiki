#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-pod-debug"

echo "=== Pod Debugging Lab — Teardown ==="

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
    echo "Namespace deletion initiated."
else
    echo "Nothing to clean up (namespace ${NAMESPACE} does not exist)."
fi

echo "=== Teardown Complete ==="
