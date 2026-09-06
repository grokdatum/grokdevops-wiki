#!/usr/bin/env bash
set -euo pipefail

NS_PRIMARY="lab-cluster-primary"
NS_SECONDARY="lab-cluster-secondary"
NS_ROUTER="lab-cluster-router"
LAB_DIR="/tmp/lab-multicluster"

echo "=== Multi-Cluster Lab Setup ==="

for ns in "${NS_PRIMARY}" "${NS_SECONDARY}" "${NS_ROUTER}"; do
    kubectl delete namespace "${ns}" --ignore-not-found=true --wait=false 2>/dev/null || true
done
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/3] Creating namespaces..."
for ns in "${NS_PRIMARY}" "${NS_SECONDARY}" "${NS_ROUTER}"; do
    kubectl create namespace "${ns}"
    kubectl label namespace "${ns}" name="${ns}" --overwrite
done

echo "[2/3] Deploying application in primary cluster..."
kubectl apply -n "${NS_PRIMARY}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  labels:
    app: webapp
    cluster: primary
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        cluster: primary
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:latest
        args:
          - "-listen=:80"
          - "-text=response-from-primary"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
EOF

echo "[3/3] Creating router namespace (skeleton)..."
# Deploy a minimal router pod — student will configure health checking
kubectl apply -n "${NS_ROUTER}" -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: router-config
data:
  PRIMARY_URL: "http://app.lab-cluster-primary.svc.cluster.local:80/"
  SECONDARY_URL: "http://app.lab-cluster-secondary.svc.cluster.local:80/"
  CHECK_INTERVAL: "5"
EOF

echo ""
echo "=== Setup Complete ==="
echo "Namespaces: ${NS_PRIMARY}, ${NS_SECONDARY}, ${NS_ROUTER}"
echo "Report directory: ${LAB_DIR}/"
echo ""
echo "Currently deployed:"
echo "  Primary:   3 replicas in ${NS_PRIMARY}"
echo "  Secondary: NOT YET DEPLOYED (your job)"
echo "  Router:    ConfigMap only (your job to deploy)"
echo ""
echo "Your mission:"
echo "  1. Deploy app in secondary cluster (namespace)"
echo "  2. Deploy a health-checking router"
echo "  3. Verify failover when primary goes down"
echo "  4. Verify failback when primary recovers"
echo "  5. Write failover report"
echo ""
echo "Run ./grade.sh when done."
