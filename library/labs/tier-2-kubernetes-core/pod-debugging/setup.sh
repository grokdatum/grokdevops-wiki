#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-pod-debug"

echo "=== Pod Debugging Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
sleep 2

echo "[1/2] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/2] Deploying 9 broken pods..."

# Pod 1: ImagePullBackOff — wrong image tag
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-image
  labels:
    lab: pod-debug
    issue: image-pull
spec:
  containers:
  - name: app
    image: nginx:99.99.99-nonexistent
    ports:
    - containerPort: 80
EOF

# Pod 2: OOMKilled — memory limit too low
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-oom
  labels:
    lab: pod-debug
    issue: oom
spec:
  containers:
  - name: app
    image: alpine:3.19
    command: ["sh", "-c", "head -c 100m /dev/urandom > /tmp/data && sleep infinity"]
    resources:
      limits:
        memory: "10Mi"
EOF

# Pod 3: Failing liveness probe — wrong port
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-liveness
  labels:
    lab: pod-debug
    issue: liveness
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 9999
      initialDelaySeconds: 2
      periodSeconds: 3
      failureThreshold: 2
EOF

# Pod 4: Failing readiness probe — wrong path
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-readiness
  labels:
    lab: pod-debug
    issue: readiness
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /nonexistent-health-endpoint
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 3
EOF

# Pod 5: Missing Secret
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-secret
  labels:
    lab: pod-debug
    issue: secret
spec:
  containers:
  - name: app
    image: alpine:3.19
    command: ["sh", "-c", "echo $DB_PASSWORD && sleep infinity"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

# Pod 6: Missing ConfigMap
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-configmap
  labels:
    lab: pod-debug
    issue: configmap
spec:
  containers:
  - name: app
    image: alpine:3.19
    command: ["sh", "-c", "cat /config/app.conf && sleep infinity"]
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    configMap:
      name: app-config
EOF

# Pod 7: Wrong command/entrypoint
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-command
  labels:
    lab: pod-debug
    issue: command
spec:
  containers:
  - name: app
    image: alpine:3.19
    command: ["/bin/nonexistent-binary"]
EOF

# Pod 8: Stuck Pending — node selector that doesn't match
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-pending
  labels:
    lab: pod-debug
    issue: pending
spec:
  nodeSelector:
    disktype: ssd-turbo-nonexistent
  containers:
  - name: app
    image: alpine:3.19
    command: ["sleep", "infinity"]
EOF

# Pod 9: Security context — read-only root FS but app tries to write to /tmp
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-security
  labels:
    lab: pod-debug
    issue: security
spec:
  containers:
  - name: app
    image: alpine:3.19
    command: ["sh", "-c", "echo data > /tmp/output.txt && sleep infinity"]
    securityContext:
      readOnlyRootFilesystem: true
EOF

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo ""
echo "Broken pods:"
kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | while read -r line; do
    echo "  ${line}"
done
echo ""
echo "Your mission: Fix all 9 pods so they are Running and Ready."
echo "Run ./grade.sh when done."
