#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-incident-sim"
LAB_DIR="/tmp/lab-incident-sim"

echo "=== Incident Simulation Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/4] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/4] Deploying database (the actual root cause: resource starvation)..."
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
          limits:
            memory: "8Mi"
            cpu: "5m"
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

echo "[3/4] Deploying dependent services (will fail due to DB issues)..."
# Order service — depends on database, will crash because DB is OOM
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  labels:
    app: order-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: app
        image: alpine:3.19
        command:
          - sh
          - -c
          - |
            apk add --no-cache redis > /dev/null 2>&1
            while true; do
              result=$(redis-cli -h database -p 6379 PING 2>&1)
              if [ "$result" != "PONG" ]; then
                echo "ERROR: database connection failed: $result"
                exit 1
              fi
              echo "OK: database connected"
              sleep 10
            done
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector:
    app: order-service
  ports:
  - port: 8080
EOF

# Payment gateway — depends on order-service
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-gateway
  labels:
    app: payment-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-gateway
  template:
    metadata:
      labels:
        app: payment-gateway
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: payment-gateway
spec:
  selector:
    app: payment-gateway
  ports:
  - port: 80
EOF

echo "[4/4] Deploying red herring (recent deployment — NOT the cause)..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  labels:
    app: notification-service
  annotations:
    deployment.kubernetes.io/revision: "5"
    kubernetes.io/change-cause: "Updated to v2.3.1 — deployed 10min before incident"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service
  template:
    metadata:
      labels:
        app: notification-service
    spec:
      containers:
      - name: app
        image: alpine:3.19
        command: ["sh", "-c", "echo 'Notification service v2.3.1 running'; sleep infinity"]
EOF

echo ""
echo "=== INCIDENT SIMULATION STARTED ==="
echo ""
echo "Three alerts fired:"
echo "  CRITICAL — Payment gateway returning 503s"
echo "  CRITICAL — Order service: database connection errors"
echo "  WARNING  — Customer-facing latency spike to 15s"
echo ""
echo "Timer started. You have 90 minutes."
echo "Output directory: ${LAB_DIR}/"
echo ""
echo "Your mission:"
echo "  1. Triage and identify all failing services"
echo "  2. Find the root cause (beware red herrings)"
echo "  3. Mitigate and restore service"
echo "  4. Write timeline, status update, and postmortem"
echo ""
echo "Run ./grade.sh when done."
