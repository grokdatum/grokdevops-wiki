#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-deploy"

echo "=== Deploy & Scale Lab Setup ==="

# Idempotent: delete namespace if it exists
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
sleep 2

echo "[1/4] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/4] Deploying incomplete frontend..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
    tier: web
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
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        # Missing: resource requests/limits
        # Missing: needs 3 replicas
EOF

echo "[3/4] Deploying broken API server..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
    tier: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:latest
        args:
          - "-listen=:8080"
          - "-text=healthy"
        ports:
        - containerPort: 8080
        # Missing: resource limits
        # Missing: readiness probe
        # Missing: needs 2 replicas
EOF

echo "[4/4] Creating placeholder for database..."
# DB deployment is intentionally NOT created — student must create it
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
data:
  POSTGRES_DB: "appdb"
  POSTGRES_USER: "appuser"
EOF

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo ""
echo "Current state:"
kubectl get all -n "${NAMESPACE}" 2>/dev/null
echo ""
echo "Your mission:"
echo "  1. Scale frontend to 3 replicas with resource limits"
echo "  2. Fix API: 2 replicas, resource limits, readiness probe"
echo "  3. Deploy PostgreSQL with a PVC"
echo "  4. Create ClusterIP services for all tiers"
echo "  5. Set up HPA for the API (2-8 replicas, 70% CPU)"
echo ""
echo "Run ./grade.sh when done."
