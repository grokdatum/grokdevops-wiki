#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-techlead"
LAB_DIR="/tmp/lab-techlead"

echo "=== Tech Lead Challenge Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
# Also clean up PoC namespaces
for ns in lab-team-alpha lab-team-beta lab-team-gamma; do
    kubectl delete namespace "${ns}" --ignore-not-found=true --wait=false 2>/dev/null || true
done
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}/decisions"
sleep 2

echo "[1/2] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/2] Creating decision templates..."

for decision in "01-cluster-strategy" "02-gitops-tooling" "03-secret-management" "04-observability-stack" "05-deployment-strategy"; do
    cat > "${LAB_DIR}/decisions/${decision}.md" <<EOF
# Decision: ${decision}

## Status
Proposed

## Context
<!-- Why is this decision needed? What problem are we solving? -->

## Options Considered
### Option A:
<!-- Describe option, pros, cons -->

### Option B:
<!-- Describe option, pros, cons -->

### Option C (if applicable):
<!-- Describe option, pros, cons -->

## Decision
<!-- What did you choose and why? -->

## Consequences
<!-- What are the implications of this decision? -->

## Trade-offs
<!-- What are you giving up? What risks remain? -->
EOF
done

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Working directory: ${LAB_DIR}/"
echo ""
echo "Decision templates created:"
ls -1 "${LAB_DIR}/decisions/"
echo ""
echo "Your mission:"
echo "  1. Complete all 5 decision documents"
echo "  2. Implement 3 PoCs in the cluster"
echo "  3. Write executive summary"
echo ""
echo "Run ./grade.sh when done."
