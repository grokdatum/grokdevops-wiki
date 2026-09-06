#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-deploy"

echo "=== Deploy & Scale Lab — Teardown ==="

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE} and all resources..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
    echo "Namespace deletion initiated (may take a moment to complete)."
else
    echo "Nothing to clean up (namespace ${NAMESPACE} does not exist)."
fi

echo "=== Teardown Complete ==="
