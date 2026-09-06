#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-logs"

echo "=== Log Analysis Lab Setup ==="

rm -rf "${LAB_ROOT}"
mkdir -p "${LAB_ROOT}"

# Generate realistic log files for 4 services during an incident window
# Incident: DB connection pool exhaustion caused cascading failures

echo "[1/4] Generating API gateway logs..."
cat > "${LAB_ROOT}/api-gateway.log" <<'EOF'
2024-01-15 03:40:12 INFO  [req-a001] api-gateway: Incoming POST /api/payments from 10.0.1.50
2024-01-15 03:40:12 INFO  [req-a002] api-gateway: Incoming GET /api/users/42 from 10.0.1.51
2024-01-15 03:42:30 INFO  [req-a003] api-gateway: Incoming POST /api/payments from 10.0.1.52
2024-01-15 03:44:15 INFO  [req-a004] api-gateway: Incoming GET /api/users/99 from 10.0.1.50
2024-01-15 03:45:00 INFO  [req-a005] api-gateway: Incoming POST /api/payments from 10.0.1.53
2024-01-15 03:47:01 INFO  [req-a006] api-gateway: Incoming POST /api/payments from 10.0.1.54
2024-01-15 03:47:01 WARN  [req-a006] api-gateway: Upstream response slow (2100ms) from payment-service
2024-01-15 03:47:15 INFO  [req-a007] api-gateway: Incoming POST /api/payments from 10.0.1.55
2024-01-15 03:47:15 ERROR [req-a007] api-gateway: Upstream timeout after 5000ms from payment-service
2024-01-15 03:47:22 ERROR [req-a008] api-gateway: Upstream timeout after 5000ms from payment-service
2024-01-15 03:47:30 ERROR [req-a009] api-gateway: Upstream timeout after 5000ms from payment-service
2024-01-15 03:47:45 ERROR [req-a010] api-gateway: Upstream timeout after 5000ms from payment-service
2024-01-15 03:48:01 ERROR [req-a011] api-gateway: Upstream timeout after 5000ms from payment-service
2024-01-15 03:48:10 ERROR [req-a012] api-gateway: Connection refused from payment-service
2024-01-15 03:48:30 ERROR [req-a013] api-gateway: Connection refused from payment-service
2024-01-15 03:49:00 WARN  [req-a014] api-gateway: Circuit breaker OPEN for payment-service
2024-01-15 03:50:00 INFO  [req-a015] api-gateway: Circuit breaker half-open, testing payment-service
2024-01-15 03:50:01 INFO  [req-a015] api-gateway: Payment-service recovered, circuit breaker CLOSED
2024-01-15 03:51:00 INFO  [req-a016] api-gateway: Incoming POST /api/payments from 10.0.1.50 — 200 OK
EOF

echo "[2/4] Generating payment service logs..."
cat > "${LAB_ROOT}/payment-service.log" <<'EOF'
2024-01-15 03:40:12 INFO  [req-a001] payment-service: Processing payment $49.99 for user 101
2024-01-15 03:40:13 INFO  [req-a001] payment-service: Payment completed successfully
2024-01-15 03:42:30 INFO  [req-a003] payment-service: Processing payment $129.00 for user 205
2024-01-15 03:42:31 INFO  [req-a003] payment-service: Payment completed successfully
2024-01-15 03:45:00 INFO  [req-a005] payment-service: Processing payment $75.50 for user 310
2024-01-15 03:45:01 INFO  [req-a005] payment-service: Payment completed successfully
2024-01-15 03:47:01 INFO  [req-a006] payment-service: Processing payment $200.00 for user 415
2024-01-15 03:47:02 WARN  [req-a006] payment-service: DB query slow (1800ms) for transaction insert
2024-01-15 03:47:03 INFO  [req-a006] payment-service: Payment completed (slow)
2024-01-15 03:47:15 INFO  [req-a007] payment-service: Processing payment $55.00 for user 420
2024-01-15 03:47:17 ERROR [req-a007] payment-service: DB connection pool exhausted — 0/20 connections available
2024-01-15 03:47:17 ERROR [req-a007] payment-service: Failed to acquire DB connection after 2000ms
2024-01-15 03:47:22 ERROR [req-a008] payment-service: DB connection pool exhausted — 0/20 connections available
2024-01-15 03:47:30 ERROR [req-a009] payment-service: DB connection pool exhausted — 0/20 connections available
2024-01-15 03:47:45 ERROR [req-a010] payment-service: DB connection pool exhausted — 0/20 connections available
2024-01-15 03:48:01 ERROR [req-a011] payment-service: DB connection pool exhausted — 0/20 connections available
2024-01-15 03:48:05 WARN  [req-a011] payment-service: Initiating connection pool reset
2024-01-15 03:48:10 ERROR payment-service: Process OOM — restarting
2024-01-15 03:49:30 INFO  payment-service: Service started, pool initialized with 20 connections
2024-01-15 03:50:01 INFO  [req-a015] payment-service: Health check passed
EOF

echo "[3/4] Generating user service logs..."
cat > "${LAB_ROOT}/user-service.log" <<'EOF'
2024-01-15 03:40:12 INFO  [req-a002] user-service: Fetching user 42
2024-01-15 03:40:12 INFO  [req-a002] user-service: User 42 returned in 15ms
2024-01-15 03:44:15 INFO  [req-a004] user-service: Fetching user 99
2024-01-15 03:44:15 INFO  [req-a004] user-service: User 99 returned in 12ms
2024-01-15 03:47:20 WARN  user-service: Increased latency on DB reads (connection pool pressure)
2024-01-15 03:48:00 ERROR user-service: DB read timeout for user profile queries
2024-01-15 03:48:30 WARN  user-service: Falling back to cache for user reads
2024-01-15 03:49:45 INFO  user-service: DB connection restored, cache fallback disabled
EOF

echo "[4/4] Generating database proxy logs..."
cat > "${LAB_ROOT}/db-proxy.log" <<'EOF'
2024-01-15 03:30:00 INFO  db-proxy: Connection pool stats: 5/20 active, 15 idle
2024-01-15 03:40:00 INFO  db-proxy: Connection pool stats: 8/20 active, 12 idle
2024-01-15 03:45:00 INFO  db-proxy: Connection pool stats: 12/20 active, 8 idle
2024-01-15 03:46:30 WARN  db-proxy: Long-running query detected (txn-8829): SELECT * FROM transactions WHERE created_at > ... — running for 45s
2024-01-15 03:46:45 WARN  db-proxy: Long-running query detected (txn-8830): SELECT * FROM transactions WHERE created_at > ... — running for 30s
2024-01-15 03:47:00 WARN  db-proxy: Connection pool stats: 19/20 active, 1 idle — HIGH PRESSURE
2024-01-15 03:47:05 ERROR db-proxy: Connection pool EXHAUSTED: 20/20 active, 0 idle, 5 waiting
2024-01-15 03:47:05 ERROR db-proxy: Root cause: 3 queries holding connections for >60s (txn-8829, txn-8830, txn-8831)
2024-01-15 03:47:10 ERROR db-proxy: Killing long-running query txn-8829 (held connection for 85s)
2024-01-15 03:47:15 ERROR db-proxy: Killing long-running query txn-8830 (held connection for 70s)
2024-01-15 03:47:20 ERROR db-proxy: Killing long-running query txn-8831 (held connection for 65s)
2024-01-15 03:47:30 WARN  db-proxy: Connection pool recovering: 18/20 active, 2 idle
2024-01-15 03:48:00 WARN  db-proxy: Connection pool recovering: 15/20 active, 5 idle
2024-01-15 03:49:00 INFO  db-proxy: Connection pool stats: 6/20 active, 14 idle — RECOVERED
2024-01-15 03:50:00 INFO  db-proxy: Connection pool stats: 4/20 active, 16 idle
EOF

echo ""
echo "=== Setup Complete ==="
echo "Log files at: ${LAB_ROOT}/"
echo ""
echo "Files:"
for f in "${LAB_ROOT}"/*.log; do
    lines=$(wc -l < "${f}")
    echo "  $(basename "${f}") (${lines} lines)"
done
echo ""
echo "Your mission:"
echo "  1. Analyze logs to find the incident root cause"
echo "  2. Trace request IDs across services"
echo "  3. Count affected requests"
echo "  4. Write incident summary to ${LAB_ROOT}/incident-summary.txt"
echo "  5. Create an error extraction script"
echo ""
echo "Run ./grade.sh when done."
