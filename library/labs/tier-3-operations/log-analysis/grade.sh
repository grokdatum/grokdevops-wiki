#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-logs"
PASS=0
FAIL=0
TOTAL=7

echo "=== Log Analysis Lab — Grading ==="
echo ""

SUMMARY="${LAB_ROOT}/incident-summary.txt"

# --- Objective 1: Incident time window identified ---
echo -n "[1/7] Incident summary file exists: "
if [[ -f "${SUMMARY}" ]]; then
    summary_size=$(wc -c < "${SUMMARY}")
    if [[ ${summary_size} -gt 50 ]]; then
        echo "PASS (${summary_size} bytes)"
        ((PASS++))
    else
        echo "FAIL (file too small — ${summary_size} bytes)"
        ((FAIL++))
    fi
else
    echo "FAIL (${SUMMARY} not found)"
    ((FAIL++))
fi

# --- Objective 2: Time window mentioned ---
echo -n "[2/7] Summary mentions incident time window (03:47): "
if [[ -f "${SUMMARY}" ]]; then
    if grep -qE "03:47|3:47" "${SUMMARY}"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (time 03:47 not found in summary)"
        ((FAIL++))
    fi
else
    echo "FAIL (no summary file)"
    ((FAIL++))
fi

# --- Objective 3: Root cause identified (connection pool / long queries) ---
echo -n "[3/7] Summary identifies root cause (connection pool or long queries): "
if [[ -f "${SUMMARY}" ]]; then
    if grep -qiE "connection pool|pool exhaust|long.running.quer|slow.quer" "${SUMMARY}"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (root cause not clearly stated)"
        ((FAIL++))
    fi
else
    echo "FAIL (no summary file)"
    ((FAIL++))
fi

# --- Objective 4: DB proxy identified as source ---
echo -n "[4/7] Summary identifies db-proxy or database as origin: "
if [[ -f "${SUMMARY}" ]]; then
    if grep -qiE "db.proxy|database|db proxy" "${SUMMARY}"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (db-proxy not mentioned as origin)"
        ((FAIL++))
    fi
else
    echo "FAIL (no summary file)"
    ((FAIL++))
fi

# --- Objective 5: Affected request count ---
echo -n "[5/7] Summary mentions affected requests (7-10 range): "
if [[ -f "${SUMMARY}" ]]; then
    # The actual number of unique error request IDs is around 7-8
    if grep -qE '[7-9]|10' "${SUMMARY}"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (expected 7-10 affected requests mentioned)"
        ((FAIL++))
    fi
else
    echo "FAIL (no summary file)"
    ((FAIL++))
fi

# --- Objective 6: Request ID tracing present ---
echo -n "[6/7] Summary references specific request IDs: "
if [[ -f "${SUMMARY}" ]]; then
    if grep -qE "req-a0[0-9]{2}" "${SUMMARY}"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no request IDs found in summary)"
        ((FAIL++))
    fi
else
    echo "FAIL (no summary file)"
    ((FAIL++))
fi

# --- Objective 7: Error extraction script exists ---
echo -n "[7/7] Error extraction script exists and is executable: "
script=""
for candidate in "${LAB_ROOT}/extract-errors.sh" "${LAB_ROOT}/errors.sh" "${LAB_ROOT}/extract_errors.sh"; do
    if [[ -f "${candidate}" && -x "${candidate}" ]]; then
        script="${candidate}"
        break
    fi
done
if [[ -n "${script}" ]]; then
    # Run it and check output
    output=$("${script}" 2>/dev/null || echo "")
    error_lines=$(echo "${output}" | grep -ci "error" || echo 0)
    if [[ ${error_lines} -gt 0 ]]; then
        echo "PASS (${error_lines} error lines extracted)"
        ((PASS++))
    else
        echo "FAIL (script runs but no errors extracted)"
        ((FAIL++))
    fi
else
    echo "FAIL (no executable extract script found)"
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
