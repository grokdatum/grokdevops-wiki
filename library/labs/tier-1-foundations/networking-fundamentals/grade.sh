#!/usr/bin/env bash
set -euo pipefail

LAB_NET="lab-net"
PREFIX="lab-net"
PASS=0
FAIL=0
TOTAL=6

echo "=== Networking Fundamentals Lab — Grading ==="
echo ""

# --- Objective 1: Network exists ---
echo -n "[1/6] Docker network '${LAB_NET}' exists: "
if docker network inspect "${LAB_NET}" > /dev/null 2>&1; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (network not found)"
    ((FAIL++))
fi

# --- Objective 2: All containers on lab-net ---
echo -n "[2/6] All containers on '${LAB_NET}': "
all_connected=true
for c in "${PREFIX}-frontend" "${PREFIX}-api" "${PREFIX}-db"; do
    if ! docker inspect "${c}" --format='{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null | grep -q "${LAB_NET}"; then
        all_connected=false
    fi
done
if ${all_connected}; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (not all containers are on ${LAB_NET})"
    ((FAIL++))
fi

# --- Objective 3: DNS resolution works ---
echo -n "[3/6] API can resolve 'db' hostname: "
dns_result=$(docker exec "${PREFIX}-api" sh -c "getent hosts ${PREFIX}-db 2>/dev/null || nslookup ${PREFIX}-db 2>/dev/null" 2>/dev/null || echo "")
if [[ -n "${dns_result}" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (DNS resolution failed)"
    ((FAIL++))
fi

# --- Objective 4: No iptables block on port 5432 ---
echo -n "[4/6] No iptables DROP on port 5432 (db): "
drop_rules=$(docker exec "${PREFIX}-db" sh -c "iptables -L INPUT -n 2>/dev/null" 2>/dev/null | grep -c "5432.*DROP" || echo 0)
if [[ "${drop_rules}" -eq 0 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (DROP rule on 5432 still present)"
    ((FAIL++))
fi

# --- Objective 5: MTU correct on api ---
echo -n "[5/6] API container MTU is 1500: "
mtu=$(docker exec "${PREFIX}-api" sh -c "cat /sys/class/net/eth0/mtu 2>/dev/null" 2>/dev/null || echo "0")
if [[ "${mtu}" == "1500" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (MTU is ${mtu} — expected 1500)"
    ((FAIL++))
fi

# --- Objective 6: No blackhole route on frontend ---
echo -n "[6/6] No blackhole route on frontend: "
blackhole=$(docker exec "${PREFIX}-frontend" sh -c "ip route show 2>/dev/null" 2>/dev/null | grep -c "blackhole" || echo 0)
if [[ "${blackhole}" -eq 0 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (blackhole route still present)"
    ((FAIL++))
fi

# --- Summary ---
echo ""
echo "=== Results ==="
echo "Passed: ${PASS}/${TOTAL}"
echo "Failed: ${FAIL}/${TOTAL}"

if [[ ${PASS} -eq ${TOTAL} ]]; then
    echo "Status: ALL OBJECTIVES COMPLETE"
    exit 0
else
    echo "Status: INCOMPLETE — review failed objectives above"
    exit 1
fi
