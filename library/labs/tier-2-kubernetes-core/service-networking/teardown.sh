#!/usr/bin/env bash
set -euo pipefail

echo "=== Service Networking Lab — Teardown ==="

for ns in lab-frontend-ns lab-backend-ns lab-data-ns; do
    if kubectl get namespace "${ns}" > /dev/null 2>&1; then
        echo "Deleting namespace ${ns}..."
        kubectl delete namespace "${ns}" --wait=false
    fi
done

echo "=== Teardown Complete ==="
