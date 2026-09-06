#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-migration"
LAB_DIR="/tmp/lab-migration"

echo "=== Zero-Downtime Migration Lab Setup ==="

kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
rm -rf "${LAB_DIR}"
mkdir -p "${LAB_DIR}"
sleep 2

echo "[1/3] Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}"

echo "[2/3] Deploying PostgreSQL 15 (source database)..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pg15-source
  labels:
    app: pg15-source
    role: source
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pg15-source
  template:
    metadata:
      labels:
        app: pg15-source
        role: source
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: "migrationpass"
        - name: POSTGRES_DB
          value: "appdb"
        args:
          - "-c"
          - "wal_level=logical"
          - "-c"
          - "max_replication_slots=5"
          - "-c"
          - "max_wal_senders=5"
---
apiVersion: v1
kind: Service
metadata:
  name: pg15-source
spec:
  selector:
    app: pg15-source
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-db-config
data:
  DB_HOST: "pg15-source"
  DB_PORT: "5432"
  DB_NAME: "appdb"
  DB_USER: "postgres"
EOF

echo "[3/3] Deploying sample application..."
kubectl apply -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 2
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
        image: alpine:3.19
        command: ["sh", "-c", "while true; do echo \"App connected to DB at ${DB_HOST}:${DB_PORT}\"; sleep 30; done"]
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-db-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: app-db-config
              key: DB_PORT
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 8080
EOF

# Wait for postgres to be ready and seed data
echo "Waiting for PostgreSQL 15 to be ready..."
kubectl wait --for=condition=Ready pod -l app=pg15-source -n "${NAMESPACE}" --timeout=90s 2>/dev/null || true
sleep 5

echo "Seeding test data..."
PG_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=pg15-source -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "${NAMESPACE}" "${PG_POD}" -- psql -U postgres -d appdb -c "
CREATE TABLE users (id serial PRIMARY KEY, name text, email text, created_at timestamp DEFAULT now());
CREATE TABLE orders (id serial PRIMARY KEY, user_id int, amount numeric, status text, created_at timestamp DEFAULT now());
CREATE TABLE products (id serial PRIMARY KEY, name text, price numeric, stock int);

INSERT INTO users (name, email) SELECT 'user_' || i, 'user_' || i || '@example.com' FROM generate_series(1, 150) AS i;
INSERT INTO products (name, price, stock) SELECT 'product_' || i, (random() * 100)::numeric(10,2), (random() * 1000)::int FROM generate_series(1, 120) AS i;
INSERT INTO orders (user_id, amount, status) SELECT (random() * 149 + 1)::int, (random() * 500)::numeric(10,2), CASE WHEN random() > 0.3 THEN 'completed' ELSE 'pending' END FROM generate_series(1, 200) AS i;
" 2>/dev/null

echo ""
echo "=== Setup Complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Report directory: ${LAB_DIR}/"
echo ""
echo "Source database: pg15-source (PostgreSQL 15)"
echo "Seeded: 150 users, 120 products, 200 orders"
echo ""
echo "Your mission:"
echo "  1. Deploy PostgreSQL 16 as target"
echo "  2. Set up logical replication source -> target"
echo "  3. Verify data sync"
echo "  4. Cut over the application"
echo "  5. Verify data integrity"
echo "  6. Write migration report"
echo ""
echo "Run ./grade.sh when done."
