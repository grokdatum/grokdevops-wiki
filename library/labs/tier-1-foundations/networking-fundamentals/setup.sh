#!/usr/bin/env bash
set -euo pipefail

LAB_NET="lab-net"
PREFIX="lab-net"

echo "=== Networking Fundamentals Lab Setup ==="

# Idempotent cleanup
for c in "${PREFIX}-frontend" "${PREFIX}-api" "${PREFIX}-db"; do
    docker rm -f "${c}" 2>/dev/null || true
done
docker network rm "${LAB_NET}" 2>/dev/null || true

echo "[1/4] Creating Docker network with intentional issues..."
# Create the network but we will NOT connect all containers to it initially
docker network create "${LAB_NET}" --driver bridge > /dev/null

echo "[2/4] Starting database container..."
# DB on the correct network but with an iptables rule blocking 5432
docker run -d --name "${PREFIX}-db" \
    --network "${LAB_NET}" \
    --cap-add NET_ADMIN \
    -e POSTGRES_PASSWORD=labpass \
    -e POSTGRES_DB=labdb \
    postgres:16-alpine > /dev/null

echo "[3/4] Starting API container on wrong network..."
# API on the DEFAULT bridge (not lab-net) — DNS won't work
docker run -d --name "${PREFIX}-api" \
    --cap-add NET_ADMIN \
    alpine:3.19 sh -c "apk add --no-cache curl > /dev/null 2>&1; sleep infinity" > /dev/null

echo "[4/4] Starting frontend container..."
# Frontend on lab-net but with a blackhole route
docker run -d --name "${PREFIX}-frontend" \
    --network "${LAB_NET}" \
    --cap-add NET_ADMIN \
    nginx:alpine > /dev/null

# Wait for containers to be ready
sleep 3

# Inject network faults
echo "Injecting network faults..."

# Block port 5432 on db container
docker exec "${PREFIX}-db" sh -c "
    apk add --no-cache iptables > /dev/null 2>&1 || true
    iptables -A INPUT -p tcp --dport 5432 -j DROP 2>/dev/null || true
" 2>/dev/null

# Set wrong MTU on api container
docker exec "${PREFIX}-api" sh -c "
    ip link set eth0 mtu 1400 2>/dev/null || true
" 2>/dev/null

# Add blackhole route on frontend
docker exec "${PREFIX}-frontend" sh -c "
    ip route add blackhole 10.0.0.0/8 2>/dev/null || true
" 2>/dev/null

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Containers running:"
echo "  - ${PREFIX}-frontend (nginx)"
echo "  - ${PREFIX}-api (alpine)"
echo "  - ${PREFIX}-db (postgres)"
echo ""
echo "Your mission:"
echo "  1. Get all containers on the '${LAB_NET}' network"
echo "  2. Fix DNS resolution between containers"
echo "  3. Remove the iptables block on the DB port"
echo "  4. Fix the MTU mismatch on the API container"
echo "  5. Remove the blackhole route on the frontend"
echo ""
echo "Run ./grade.sh when done."
