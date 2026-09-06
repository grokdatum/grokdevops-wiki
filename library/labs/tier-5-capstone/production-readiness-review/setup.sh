#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-prr"
LAB_DIR="/tmp/lab-prr"

echo "=== Production Readiness Review Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/2] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/2] Deploying non-production-ready service..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-processor
  labels:
    app: order-processor
    team: commerce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-processor
  template:
    metadata:
      labels:
        app: order-processor
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        # Missing: resource limits
        # Missing: probes
        # Missing: security context
        # Missing: prometheus annotations
---
apiVersion: v1
kind: Service
metadata:
  name: order-processor
spec:
  selector:
    app: order-processor
  ports:
  - port: 8080
    targetPort: 80
EOF
# Missing: HPA, PDB, NetworkPolicy, monitoring, runbook

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Output directory: ${LAB_DIR}/"
echo ""
echo "Deployed: order-processor (1 replica, no hardening)"
echo ""
echo "Production Readiness Checklist:"
echo "  [ ] Resource limits"
echo "  [ ] Multiple replicas + PDB"
echo "  [ ] Health probes"
echo "  [ ] Monitoring annotations"
echo "  [ ] Security context"
echo "  [ ] NetworkPolicy"
echo "  [ ] Runbook"
echo "  [ ] PRR report"
echo ""
echo "Your mission: Make this service production-ready."
echo "Run ./grade.sh when done."
