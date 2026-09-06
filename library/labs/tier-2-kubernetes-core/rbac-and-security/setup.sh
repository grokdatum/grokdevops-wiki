#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-rbac"

echo "=== RBAC & Security Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
# Clean up cluster-scoped resources from previous runs
kubectl delete clusterrole lab-ops-role lab-auditor-role --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrolebinding lab-ops-binding lab-auditor-binding --ignore-not-found=true 2>/dev/null || true
sleep 2

echo "[1/2] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/2] Creating ServiceAccounts (no roles yet)..."
for sa in dev-sa ops-sa auditor-sa; do
    kubectl create serviceaccount "${sa}" -n "${NAMESPACE}"
done

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo ""
echo "ServiceAccounts created (no roles or bindings yet):"
echo "  - dev-sa     (should get namespace-scoped CRUD)"
echo "  - ops-sa     (should get cluster-wide read + deployment CRUD)"
echo "  - auditor-sa (should get cluster-wide read-only)"
echo ""
echo "Your mission:"
echo "  1. Create Roles/ClusterRoles for each SA"
echo "  2. Create RoleBindings/ClusterRoleBindings"
echo "  3. Verify permissions with 'kubectl auth can-i'"
echo ""
echo "Run ./grade.sh when done."
