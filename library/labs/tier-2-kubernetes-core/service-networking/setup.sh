#!/usr/bin/env bash
set -euo pipefail

NS_FE="lab-frontend-ns"
NS_BE="lab-backend-ns"
NS_DATA="lab-data-ns"

echo "=== Service Networking Lab Setup ==="

# Idempotent cleanup
for ns in "${NS_FE}" "${NS_BE}" "${NS_DATA}"; do
    kubectl delete namespace "${ns}" --ignore-not-found=true --wait=false 2>/dev/null || true
done
sleep 2

echo "[1/4] Creating namespaces..."
for ns in "${NS_FE}" "${NS_BE}" "${NS_DATA}"; do
    kubectl create namespace "${ns}"
    kubectl label namespace "${ns}" name="${ns}" --overwrite
done

echo "[2/4] Deploying frontend (nginx)..."
kubectl apply -n "${NS_FE}" -f - <<'EOF'
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
      - name: nginx
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
    targetPort: 80
EOF

echo "[3/4] Deploying backend (echo API)..."
kubectl apply -n "${NS_BE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
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
      - name: echo
        image: hashicorp/http-echo:latest
        args:
          - "-listen=:8080"
          - "-text=api-response-ok"
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
EOF

echo "[4/4] Deploying data tier (redis)..."
kubectl apply -n "${NS_DATA}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
EOF

echo ""
echo "=== Setup Complete ==="
echo "Namespaces: ${NS_FE}, ${NS_BE}, ${NS_DATA}"
echo ""
echo "Deployed services (no Ingress or NetworkPolicies yet):"
echo "  frontend -> ${NS_FE}:80"
echo "  api      -> ${NS_BE}:8080"
echo "  redis    -> ${NS_DATA}:6379"
echo ""
echo "Your mission:"
echo "  1. Configure Ingress for /api/* -> backend"
echo "  2. Add NetworkPolicies for segmentation"
echo "  3. Verify allowed and denied paths"
echo ""
echo "Run ./grade.sh when done."
