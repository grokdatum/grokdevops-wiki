#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-techlead"
LAB_DIR="/tmp/lab-techlead"

echo "=== Tech Lead Challenge Lab — Teardown ==="

for ns in "${NAMESPACE}" lab-team-alpha lab-team-beta lab-team-gamma; do
    if kubectl get namespace "${ns}" > /dev/null 2>&1; then
        echo "Deleting namespace ${ns}..."
        kubectl delete namespace "${ns}" --wait=false
    fi
done

rm -rf "${LAB_DIR}" && echo "Removed ${LAB_DIR}" || true

echo "=== Teardown Complete ==="
