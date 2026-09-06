#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-incident"
LAB_DIR="/tmp/lab-incident"

echo "=== Incident Response Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/3] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/3] Deploying application stack (with hidden issues)..."

# Frontend — healthy
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 2
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
            memory: "64Mi"
          limits:
            memory: "128Mi"
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

# Payment API — BROKEN: references missing secret and has wrong env var
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: payment-config
type: Opaque
stringData:
  DB_HOST: "db.lab-incident.svc.cluster.local"
  DB_PORT: "5432"
  # DB_PASSWORD intentionally missing — this is the bug
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  labels:
    app: payment-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
    spec:
      containers:
      - name: api
        image: alpine:3.19
        command:
          - sh
          - -c
          - |
            if [ -z "$DB_PASSWORD" ]; then
              echo "FATAL: DB_PASSWORD not set — cannot connect to database"
              exit 1
            fi
            echo "Payment API started successfully"
            sleep infinity
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: payment-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: payment-config
              key: DB_PORT
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: payment-config
              key: DB_PASSWORD
              optional: false
        resources:
          requests:
            memory: "64Mi"
          limits:
            memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: payment-api
spec:
  selector:
    app: payment-api
  ports:
  - port: 8080
    targetPort: 8080
EOF

# Database — healthy
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  labels:
    app: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
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
  name: db
spec:
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 6379
EOF

echo "[3/3] Waiting for pods to settle..."
sleep 5

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Output directory: ${LAB_DIR}/"
echo ""
echo "=== P1 ALERT: Payment processing failure rate > 50% ==="
echo ""
echo "Current pod status:"
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "Your mission (incident commander):"
echo "  1. Triage — find the broken component"
echo "  2. Diagnose — determine root cause"
echo "  3. Mitigate — fix it"
echo "  4. Verify — confirm all pods healthy"
echo "  5. Write timeline to ${LAB_DIR}/timeline.txt"
echo "  6. Write postmortem to ${LAB_DIR}/postmortem.txt"
echo ""
echo "Run ./grade.sh when done."
