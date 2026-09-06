#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-chaos"
LAB_DIR="/tmp/lab-chaos"

echo "=== Chaos Engineering Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/3] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/3] Deploying resilient application stack..."

# Frontend — 3 replicas
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 3
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
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
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

# API — 3 replicas with NET_ADMIN for tc
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 3
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
          - "-text=api-healthy"
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
            ephemeral-storage: "100Mi"
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
EOF

# Database — single replica
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
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  selector:
    app: database
  ports:
  - port: 6379
EOF

echo "[3/3] Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod -l app=frontend -n "${NAMESPACE}" --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Ready pod -l app=api -n "${NAMESPACE}" --timeout=60s 2>/dev/null || true

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Report directory: ${LAB_DIR}/"
echo ""
echo "Deployed:"
kubectl get pods -n "${NAMESPACE}" --no-headers
echo ""
echo "Your mission: Run 5 chaos experiments and write a resilience report."
echo "Run ./grade.sh when done."
