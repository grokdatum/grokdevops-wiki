#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-arch-review"
LAB_DIR="/tmp/lab-arch"

echo "=== Architecture Review Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/2] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/2] Deploying flawed architecture..."

# Monolithic API — single replica, no probes, no limits, handles everything
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monolith-api
  labels:
    app: monolith-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: monolith-api
  template:
    metadata:
      labels:
        app: monolith-api
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
        # No resource limits
        # No probes
        # No security context
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: monolith-api
  ports:
  - port: 80
EOF

# Database — single replica, no backup, directly accessible from all pods
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  labels:
    app: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: "weakpassword"
        - name: POSTGRES_DB
          value: "appdb"
        # No resource limits
        # No persistent storage
---
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  selector:
    app: database
  ports:
  - port: 5432
EOF

# Frontend — single replica
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
EOF
# No caching layer, no NetworkPolicies, no PDB, no HPA

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Output directory: ${LAB_DIR}/"
echo ""
echo "Deployed (all flawed):"
echo "  monolith-api — single replica, no limits, no probes"
echo "  database     — single replica, no persistent storage"
echo "  frontend     — single replica, no hardening"
echo "  (no cache, no NetworkPolicies, no PDB)"
echo ""
echo "Your mission:"
echo "  1. Review and document architectural flaws"
echo "  2. Implement at least 5 critical fixes"
echo "  3. Write review document"
echo ""
echo "Run ./grade.sh when done."
