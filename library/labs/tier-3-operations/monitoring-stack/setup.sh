#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-monitoring"

echo "=== Monitoring Stack Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
sleep 2

echo "[1/3] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/3] Creating partial Prometheus configuration..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    # TODO: Add rule_files section for alerting rules
    # rule_files:
    #   - /etc/prometheus/rules/*.yml

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      # TODO: Add kubernetes pod discovery
      # Hint: use kubernetes_sd_configs with role: pod
EOF

echo "[3/3] Creating RBAC for Prometheus (needs to discover pods)..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: lab-prometheus
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lab-prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: lab-prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: lab-monitoring
EOF

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo ""
echo "Created:"
echo "  - Partial Prometheus ConfigMap (needs pod discovery + alert rules)"
echo "  - RBAC for Prometheus ServiceAccount"
echo ""
echo "Your mission:"
echo "  1. Deploy Prometheus with the ConfigMap mounted"
echo "  2. Add kubernetes pod discovery to the scrape config"
echo "  3. Add alert rules for pod restarts"
echo "  4. Deploy Grafana with Prometheus datasource"
echo "  5. Deploy a sample app with metrics"
echo ""
echo "Run ./grade.sh when done."
