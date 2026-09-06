#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="lab-storage"
PASS=0
FAIL=0
TOTAL=6

echo "=== Storage & State Lab — Grading ==="
echo ""

# --- Objective 1: PVC exists ---
echo -n "[1/6] PersistentVolumeClaim exists: "
pvc_count=$(kubectl get pvc -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [[ ${pvc_count} -gt 0 ]]; then
    pvc_status=$(kubectl get pvc -n "${NAMESPACE}" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    echo "PASS (${pvc_count} PVCs, status=${pvc_status})"
    ((PASS++))
else
    echo "FAIL (no PVCs found)"
    ((FAIL++))
fi

# --- Objective 2: StatefulSet running ---
echo -n "[2/6] PostgreSQL runs as StatefulSet: "
ss_name=$(kubectl get statefulset -n "${NAMESPACE}" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "${ss_name}" ]]; then
    ss_name=$(kubectl get statefulset -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi
if [[ -n "${ss_name}" ]]; then
    ready=$(kubectl get statefulset "${ss_name}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
    echo "PASS (name=${ss_name}, ready=${ready})"
    ((PASS++))
else
    echo "FAIL (no StatefulSet found)"
    ((FAIL++))
fi

# --- Objective 3: Database has test data ---
echo -n "[3/6] Database contains test table with 5+ rows: "
pg_pod=$(kubectl get pods -n "${NAMESPACE}" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${pg_pod}" ]]; then
    row_count=$(kubectl exec -n "${NAMESPACE}" "${pg_pod}" -- psql -U postgres -d labdb -t -c "SELECT count(*) FROM items;" 2>/dev/null | tr -d ' ' || echo "0")
    if [[ "${row_count}" -ge 5 ]]; then
        echo "PASS (${row_count} rows)"
        ((PASS++))
    else
        echo "FAIL (${row_count} rows — need at least 5)"
        ((FAIL++))
    fi
else
    echo "FAIL (no postgres pod found)"
    ((FAIL++))
fi

# --- Objective 4: Data survives pod deletion ---
echo -n "[4/6] Data persists after pod restart: "
if [[ -n "${pg_pod}" ]]; then
    # Delete the pod and wait for StatefulSet to recreate it
    kubectl delete pod "${pg_pod}" -n "${NAMESPACE}" --wait=true --timeout=30s 2>/dev/null || true
    echo -n "(waiting for restart) "
    sleep 10
    # Wait for pod to be ready
    kubectl wait --for=condition=Ready pod -l app=postgres -n "${NAMESPACE}" --timeout=60s 2>/dev/null || true
    pg_pod_new=$(kubectl get pods -n "${NAMESPACE}" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "${pg_pod_new}" ]]; then
        row_count=$(kubectl exec -n "${NAMESPACE}" "${pg_pod_new}" -- psql -U postgres -d labdb -t -c "SELECT count(*) FROM items;" 2>/dev/null | tr -d ' ' || echo "0")
        if [[ "${row_count}" -ge 5 ]]; then
            echo "PASS (${row_count} rows after restart)"
            ((PASS++))
        else
            echo "FAIL (data lost — ${row_count} rows after restart)"
            ((FAIL++))
        fi
    else
        echo "FAIL (pod did not restart)"
        ((FAIL++))
    fi
else
    echo "FAIL (no pod to test)"
    ((FAIL++))
fi

# --- Objective 5: Backup file exists ---
echo -n "[5/6] Backup file exists in /tmp/lab-storage-backups/: "
backup_file=$(ls /tmp/lab-storage-backups/*.sql 2>/dev/null | head -1 || echo "")
if [[ -n "${backup_file}" && -s "${backup_file}" ]]; then
    size=$(stat -c%s "${backup_file}")
    echo "PASS (${backup_file}, ${size} bytes)"
    ((PASS++))
else
    echo "FAIL (no .sql backup file found)"
    ((FAIL++))
fi

# --- Objective 6: Backup contains valid SQL ---
echo -n "[6/6] Backup contains table data: "
if [[ -n "${backup_file}" ]]; then
    if grep -q "items" "${backup_file}" 2>/dev/null; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (backup does not reference 'items' table)"
        ((FAIL++))
    fi
else
    echo "FAIL (no backup to check)"
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
