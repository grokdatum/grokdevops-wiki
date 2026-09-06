#!/usr/bin/env bash
set -euo pipefail

LAB_NET="lab-net"
PREFIX="lab-net"

echo "=== Networking Fundamentals Lab — Teardown ==="

for c in "${PREFIX}-frontend" "${PREFIX}-api" "${PREFIX}-db"; do
    docker rm -f "${c}" 2>/dev/null && echo "Removed container ${c}" || true
done

docker network rm "${LAB_NET}" 2>/dev/null && echo "Removed network ${LAB_NET}" || true

echo "=== Teardown Complete ==="
