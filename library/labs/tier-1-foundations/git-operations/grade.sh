#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-git-operations"
PASS=0
FAIL=0
TOTAL=5

echo "=== Git Operations Lab — Grading ==="
echo ""

cd "${LAB_ROOT}" 2>/dev/null || { echo "FATAL: ${LAB_ROOT} not found"; exit 1; }

# --- Objective 1: Detached HEAD recovered ---
echo -n "[1/5] Detached HEAD work recovered on a branch: "
detached_sha=""
[[ -f /tmp/lab-git-ops-detached-sha ]] && detached_sha=$(cat /tmp/lab-git-ops-detached-sha)
if [[ -n "${detached_sha}" ]]; then
    # Check if that SHA is reachable from any branch
    branch=$(git branch --contains "${detached_sha}" 2>/dev/null | head -1 | sed 's/^[* ]*//')
    if [[ -n "${branch}" ]]; then
        echo "PASS (on branch '${branch}')"
        ((PASS++))
    else
        echo "FAIL (commit ${detached_sha:0:8} not on any branch)"
        ((FAIL++))
    fi
else
    echo "SKIP (reference SHA not found — re-run setup.sh)"
    ((FAIL++))
fi

# --- Objective 2: Force-pushed commits restored ---
echo -n "[2/5] Force-pushed commits restored (features A, B, C): "
log_output=$(git log --oneline --all 2>/dev/null || echo "")
has_a=$(echo "${log_output}" | grep -c "feature A" || echo 0)
has_b=$(echo "${log_output}" | grep -c "feature B" || echo 0)
has_c=$(echo "${log_output}" | grep -c "feature C" || echo 0)
if [[ ${has_a} -gt 0 && ${has_b} -gt 0 && ${has_c} -gt 0 ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (missing commits — found A:${has_a} B:${has_b} C:${has_c})"
    ((FAIL++))
fi

# --- Objective 3: Merge conflict resolved ---
echo -n "[3/5] Merge conflict resolved: "
# Check for unmerged entries in git status
git_status=$(git status --porcelain 2>/dev/null || echo "UU")
if echo "${git_status}" | grep -q "^UU\|^AA\|^DD"; then
    echo "FAIL (unmerged files remain)"
    ((FAIL++))
elif echo "${git_status}" | grep -q "MERGE_HEAD" || [[ -f "${LAB_ROOT}/.git/MERGE_HEAD" ]]; then
    echo "FAIL (merge still in progress)"
    ((FAIL++))
else
    if [[ -f "${LAB_ROOT}/conflict-file.txt" ]]; then
        if grep -q "<<<<<<" "${LAB_ROOT}/conflict-file.txt" 2>/dev/null; then
            echo "FAIL (conflict markers still in file)"
            ((FAIL++))
        else
            echo "PASS"
            ((PASS++))
        fi
    else
        echo "PASS (file resolved)"
        ((PASS++))
    fi
fi

# --- Objective 4: Dangling commit recovered ---
echo -n "[4/5] Secret feature commit recovered: "
secret_sha=""
[[ -f /tmp/lab-git-ops-secret-sha ]] && secret_sha=$(cat /tmp/lab-git-ops-secret-sha)
if [[ -n "${secret_sha}" ]]; then
    branch=$(git branch --contains "${secret_sha}" 2>/dev/null | head -1 | sed 's/^[* ]*//')
    if [[ -n "${branch}" ]]; then
        echo "PASS (on branch '${branch}')"
        ((PASS++))
    else
        echo "FAIL (commit ${secret_sha:0:8} not on any branch)"
        ((FAIL++))
    fi
else
    echo "SKIP (reference SHA not found — re-run setup.sh)"
    ((FAIL++))
fi

# --- Objective 5: Index fixed ---
echo -n "[5/5] Git index is valid (git status works): "
if git status > /dev/null 2>&1; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (git status still fails)"
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
