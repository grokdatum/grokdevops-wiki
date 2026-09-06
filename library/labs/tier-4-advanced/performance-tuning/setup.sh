#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-perf"
LAB_DIR="/tmp/lab-perf"

echo "=== Performance Tuning Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/2] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/2] Deploying poorly configured application..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "5m"
            memory: "16Mi"
          limits:
            cpu: "10m"
            memory: "24Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 3
          failureThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
EOF
# No HPA, no PDB — student must add them

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Report directory: ${LAB_DIR}/"
echo ""
echo "Known symptoms:"
echo "  - Response times > 3 seconds"
echo "  - Pods occasionally crash-loop"
echo "  - No autoscaling during traffic spikes"
echo "  - Restarts during rolling updates"
echo ""
echo "Your mission: Find and fix 5 performance bottlenecks."
echo "Write findings to ${LAB_DIR}/tuning-report.txt"
echo "Run ./grade.sh when done."
