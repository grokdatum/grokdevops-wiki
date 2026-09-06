#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-oncall"
LAB_DIR="/tmp/lab-oncall"

echo "=== On-Call Shift Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/4] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/4] Deploying 6-service production stack..."

# Frontend
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels: { app: frontend }
spec:
  replicas: 2
  selector:
    matchLabels: { app: frontend }
  template:
    metadata:
      labels: { app: frontend }
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports: [{ containerPort: 80 }]
        resources:
          requests: { cpu: "50m", memory: "64Mi" }
          limits: { cpu: "100m", memory: "128Mi" }
---
apiVersion: v1
kind: Service
metadata: { name: frontend }
spec:
  selector: { app: frontend }
  ports: [{ port: 80 }]
EOF

# API Gateway
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  labels: { app: api-gateway }
spec:
  replicas: 2
  selector:
    matchLabels: { app: api-gateway }
  template:
    metadata:
      labels: { app: api-gateway }
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:latest
        args: ["-listen=:8080", "-text=gateway-ok"]
        ports: [{ containerPort: 8080 }]
        resources:
          requests: { cpu: "50m", memory: "64Mi" }
          limits: { cpu: "100m", memory: "128Mi" }
---
apiVersion: v1
kind: Service
metadata: { name: api-gateway }
spec:
  selector: { app: api-gateway }
  ports: [{ port: 8080 }]
EOF

# User service — ALERT 1: Missing ConfigMap causes crash
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  labels: { app: user-service }
spec:
  replicas: 2
  selector:
    matchLabels: { app: user-service }
  template:
    metadata:
      labels: { app: user-service }
    spec:
      containers:
      - name: app
        image: alpine:3.19
        command: ["sh", "-c", "cat /config/settings.yaml && sleep infinity"]
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests: { cpu: "50m", memory: "64Mi" }
          limits: { cpu: "100m", memory: "128Mi" }
      volumes:
      - name: config
        configMap:
          name: user-service-config
EOF

# Payment service — ALERT 2: Low memory limit, will hit pressure
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  labels: { app: payment-service }
spec:
  replicas: 1
  selector:
    matchLabels: { app: payment-service }
  template:
    metadata:
      labels: { app: payment-service }
    spec:
      containers:
      - name: app
        image: alpine:3.19
        command: ["sh", "-c", "head -c 20m /dev/urandom > /tmp/cache && echo 'Payment service running' && sleep infinity"]
        resources:
          requests: { cpu: "50m", memory: "16Mi" }
          limits: { cpu: "100m", memory: "32Mi" }
---
apiVersion: v1
kind: Service
metadata: { name: payment-service }
spec:
  selector: { app: payment-service }
  ports: [{ port: 8080 }]
EOF

# Notification service — healthy
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  labels: { app: notification-service }
spec:
  replicas: 1
  selector:
    matchLabels: { app: notification-service }
  template:
    metadata:
      labels: { app: notification-service }
    spec:
      containers:
      - name: app
        image: alpine:3.19
        command: ["sh", "-c", "echo 'Notification service running'; sleep infinity"]
        resources:
          requests: { cpu: "50m", memory: "64Mi" }
          limits: { cpu: "100m", memory: "128Mi" }
---
apiVersion: v1
kind: Service
metadata: { name: notification-service }
spec:
  selector: { app: notification-service }
  ports: [{ port: 8080 }]
EOF

# Database
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  labels: { app: database }
spec:
  replicas: 1
  selector:
    matchLabels: { app: database }
  template:
    metadata:
      labels: { app: database }
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports: [{ containerPort: 6379 }]
        resources:
          requests: { cpu: "50m", memory: "64Mi" }
          limits: { cpu: "200m", memory: "128Mi" }
---
apiVersion: v1
kind: Service
metadata: { name: database }
spec:
  selector: { app: database }
  ports: [{ port: 6379 }]
EOF

echo "[3/4] Creating alert simulation markers..."
# Write alert descriptions
cat > "${LAB_DIR}/alerts.txt" <<'EOF'
ALERT 1 [P1] — user-service CrashLoopBackOff
  Symptom: user-service pods are crash-looping
  Action required: Fix the issue to restore service

ALERT 2 [P2] — payment-service high memory / OOM
  Symptom: payment-service pods OOM-killed or restarting
  Action required: Increase limits or optimize memory usage

ALERT 3 [P3] — Certificate expiry warning
  Symptom: TLS certificate expires in 29 days
  Action required: Acknowledge, plan renewal

ALERT 4 [P2] — Database connection count spike
  Symptom: Redis connections above normal threshold
  Action required: Investigate source of connections

ALERT 5 [P3] — Disk pressure warning on node
  Symptom: Node reports disk pressure condition
  Action required: Investigate, clean up if needed
EOF

echo "[4/4] Waiting for initial state to settle..."
sleep 5

echo ""
echo "=== ON-CALL SHIFT STARTED ==="
echo ""
echo "You are now on-call. Check ${LAB_DIR}/alerts.txt for alert descriptions."
echo ""
echo "Current state:"
kubectl get pods -n "${NAMESPACE}" --no-headers
echo ""
echo "Your mission:"
echo "  1. Respond to each alert appropriately"
echo "  2. Fix P1/P2 issues"
echo "  3. Acknowledge P3 issues"
echo "  4. Write shift log and handoff notes"
echo ""
echo "Run ./grade.sh when done."
