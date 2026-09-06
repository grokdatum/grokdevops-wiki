#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-platform"
LAB_DIR="/tmp/lab-platform"

echo "=== Platform Engineering Lab — Teardown ==="

# Uninstall Helm releases
for release in team-alpha team-beta; do
    helm uninstall "${release}" -n "${NAMESPACE}" 2>/dev/null && echo "Uninstalled ${release}" || true
done

if kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Deleting namespace ${NAMESPACE}..."
    kubectl delete namespace "${NAMESPACE}" --wait=false
fi

rm -rf "${LAB_DIR}" && echo "Removed ${LAB_DIR}" || true

echo "=== Teardown Complete ==="
