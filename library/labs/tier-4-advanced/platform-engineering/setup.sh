#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-platform"
LAB_DIR="/tmp/lab-platform"

echo "=== Platform Engineering Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}/charts/service-template/templates"
sleep 2

echo "[1/3] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/3] Creating chart skeleton..."
cat > "${LAB_DIR}/charts/service-template/Chart.yaml" <<'EOF'
apiVersion: v2
name: service-template
description: Internal developer platform — standard microservice template
version: 1.0.0
appVersion: "1.0"
type: application
EOF

cat > "${LAB_DIR}/charts/service-template/values.yaml" <<'EOF'
# TODO: Define sensible defaults for the service template
#
# Required fields:
#   image.repository — container image
#   image.tag — image tag
#   replicas — number of replicas
#   port — container port
#   resources — CPU/memory requests and limits
#   probes — liveness and readiness probe config
#   metrics.enabled — whether to add Prometheus annotations
#   hpa — HPA configuration
#   pdb — PDB configuration

image:
  repository: nginx
  tag: alpine

replicas: 2
port: 80

# TODO: Add resources, probes, metrics, hpa, pdb defaults
EOF

echo "[3/3] Creating sample values files..."
cat > "${LAB_DIR}/alpha-values.yaml" <<'EOF'
# Team Alpha — API service
image:
  repository: hashicorp/http-echo
  tag: latest
replicas: 2
port: 8080
EOF

cat > "${LAB_DIR}/beta-values.yaml" <<'EOF'
# Team Beta — Web frontend
image:
  repository: nginx
  tag: alpine
replicas: 3
port: 80
EOF

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Chart directory: ${LAB_DIR}/charts/service-template/"
echo ""
echo "Skeleton created:"
echo "  Chart.yaml — metadata (done)"
echo "  values.yaml — needs defaults"
echo "  templates/ — needs deployment, service, hpa, pdb, sa"
echo ""
echo "Your mission:"
echo "  1. Implement the Helm chart templates"
echo "  2. Set sensible defaults in values.yaml"
echo "  3. Install two instances (team-alpha, team-beta)"
echo "  4. Verify both are running"
echo ""
echo "Run ./grade.sh when done."
