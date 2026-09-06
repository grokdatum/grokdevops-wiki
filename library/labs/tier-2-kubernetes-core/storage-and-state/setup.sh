#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-storage"

echo "=== Storage & State Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
sleep 2

echo "[1/2] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/2] Deploying broken PostgreSQL (Deployment, no PVC)..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pg-broken
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: "labpass123"
        - name: POSTGRES_DB
          value: "labdb"
        # No volume mount — data will be lost on restart!
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
EOF

# Create backup directory
mkdir -p /tmp/lab-storage-backups

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo ""
echo "Current state: PostgreSQL is running as a Deployment with no persistent storage."
echo "If you delete the pod, all data is lost."
echo ""
echo "Your mission:"
echo "  1. Replace the Deployment with a StatefulSet"
echo "  2. Add a PVC for persistent storage"
echo "  3. Seed the database with test data"
echo "  4. Verify data survives pod restart"
echo "  5. Implement backup/restore with pg_dump"
echo ""
echo "Backup directory: /tmp/lab-storage-backups/"
echo "Run ./grade.sh when done."
