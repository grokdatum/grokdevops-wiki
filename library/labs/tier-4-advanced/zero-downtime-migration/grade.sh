#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-migration"
LAB_DIR="/tmp/lab-migration"
PASS=0
FAIL=0
TOTAL=7

echo "=== Zero-Downtime Migration Lab — Grading ==="
echo ""

# --- Objective 1: PG16 target is running ---
echo -n "[1/7] PostgreSQL 16 target is running: "
pg16_pod=$(kubectl get pods -n "${NAMESPACE}" -l role=target -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "${pg16_pod}" ]]; then
    pg16_pod=$(kubectl get pods -n "${NAMESPACE}" -o name 2>/dev/null | grep -i "pg16\|target" | head -1 | sed 's|pod/||' || echo "")
fi
if [[ -n "${pg16_pod}" ]]; then
    phase=$(kubectl get pod "${pg16_pod}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    echo "PASS (${pg16_pod}, phase=${phase})"
    ((PASS++))
else
    echo "FAIL (no PostgreSQL 16 target pod found — label with role=target)"
    ((FAIL++))
fi

# --- Objective 2: Source has test data ---
echo -n "[2/7] Source database has seeded data: "
pg15_pod=$(kubectl get pods -n "${NAMESPACE}" -l app=pg15-source -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${pg15_pod}" ]]; then
    user_count=$(kubectl exec -n "${NAMESPACE}" "${pg15_pod}" -- psql -U postgres -d appdb -t -c "SELECT count(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "0")
    if [[ "${user_count}" -ge 100 ]]; then
        echo "PASS (${user_count} users)"
        ((PASS++))
    else
        echo "FAIL (${user_count} users — expected 100+)"
        ((FAIL++))
    fi
else
    echo "FAIL (source pod not found)"
    ((FAIL++))
fi

# --- Objective 3: Target has replicated data ---
echo -n "[3/7] Target database has replicated data: "
if [[ -n "${pg16_pod}" ]]; then
    target_users=$(kubectl exec -n "${NAMESPACE}" "${pg16_pod}" -- psql -U postgres -d appdb -t -c "SELECT count(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "0")
    if [[ "${target_users}" -ge 100 ]]; then
        echo "PASS (${target_users} users on target)"
        ((PASS++))
    else
        echo "FAIL (${target_users} users on target — expected 100+)"
        ((FAIL++))
    fi
else
    echo "FAIL (no target pod to check)"
    ((FAIL++))
fi

# --- Objective 4: Row counts match ---
echo -n "[4/7] Row counts match between source and target: "
if [[ -n "${pg15_pod}" && -n "${pg16_pod}" ]]; then
    src_count=$(kubectl exec -n "${NAMESPACE}" "${pg15_pod}" -- psql -U postgres -d appdb -t -c "SELECT count(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "-1")
    tgt_count=$(kubectl exec -n "${NAMESPACE}" "${pg16_pod}" -- psql -U postgres -d appdb -t -c "SELECT count(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "-2")
    if [[ "${src_count}" == "${tgt_count}" && "${src_count}" -gt 0 ]]; then
        echo "PASS (both have ${src_count} users)"
        ((PASS++))
    else
        echo "FAIL (source=${src_count}, target=${tgt_count})"
        ((FAIL++))
    fi
else
    echo "FAIL (pods not available)"
    ((FAIL++))
fi

# --- Objective 5: App points to new database ---
echo -n "[5/7] Application cutover to new database: "
db_host=$(kubectl get configmap app-db-config -n "${NAMESPACE}" -o jsonpath='{.data.DB_HOST}' 2>/dev/null || echo "")
if echo "${db_host}" | grep -qiE "pg16|target|new"; then
    echo "PASS (DB_HOST=${db_host})"
    ((PASS++))
else
    echo "FAIL (DB_HOST=${db_host} — should point to PG16 target)"
    ((FAIL++))
fi

# --- Objective 6: App pods running ---
echo -n "[6/7] Application pods are healthy: "
app_running=$(kubectl get pods -n "${NAMESPACE}" -l app=webapp --no-headers 2>/dev/null | grep -c "Running" || echo 0)
if [[ ${app_running} -ge 1 ]]; then
    echo "PASS (${app_running} pods)"
    ((PASS++))
else
    echo "FAIL (${app_running} running pods)"
    ((FAIL++))
fi

# --- Objective 7: Migration report ---
echo -n "[7/7] Migration report exists: "
if [[ -f "${LAB_DIR}/migration-report.txt" ]]; then
    size=$(wc -c < "${LAB_DIR}/migration-report.txt")
    if [[ ${size} -ge 300 ]]; then
        echo "PASS (${size} bytes)"
        ((PASS++))
    else
        echo "FAIL (${size} bytes — need at least 300)"
        ((FAIL++))
    fi
else
    echo "FAIL (${LAB_DIR}/migration-report.txt not found)"
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
