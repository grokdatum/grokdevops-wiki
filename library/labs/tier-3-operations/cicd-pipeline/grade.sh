#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-cicd"
PASS=0
FAIL=0
TOTAL=7
WORKFLOW="${LAB_ROOT}/.github/workflows/ci.yml"

echo "=== CI/CD Pipeline Lab — Grading ==="
echo ""

# --- Objective 1: Workflow file exists ---
echo -n "[1/7] Workflow file exists at .github/workflows/ci.yml: "
if [[ -f "${WORKFLOW}" ]]; then
    echo "PASS"
    ((PASS++))
else
    # Check for alternative names
    alt=$(ls "${LAB_ROOT}/.github/workflows/"*.yml 2>/dev/null | head -1 || echo "")
    if [[ -n "${alt}" ]]; then
        WORKFLOW="${alt}"
        echo "PASS (found $(basename "${alt}"))"
        ((PASS++))
    else
        echo "FAIL (no workflow file found)"
        ((FAIL++))
    fi
fi

# --- Objective 2: Lint job ---
echo -n "[2/7] Pipeline has lint job with flake8: "
if [[ -f "${WORKFLOW}" ]]; then
    has_lint=$(grep -c "lint" "${WORKFLOW}" || echo 0)
    has_flake8=$(grep -c "flake8" "${WORKFLOW}" || echo 0)
    if [[ ${has_lint} -gt 0 && ${has_flake8} -gt 0 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (lint=${has_lint}, flake8=${has_flake8})"
        ((FAIL++))
    fi
else
    echo "FAIL (no workflow file)"
    ((FAIL++))
fi

# --- Objective 3: Test job with pytest ---
echo -n "[3/7] Pipeline has test job with pytest: "
if [[ -f "${WORKFLOW}" ]]; then
    has_test=$(grep -c "test" "${WORKFLOW}" || echo 0)
    has_pytest=$(grep -c "pytest" "${WORKFLOW}" || echo 0)
    if [[ ${has_test} -gt 0 && ${has_pytest} -gt 0 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (test=${has_test}, pytest=${has_pytest})"
        ((FAIL++))
    fi
else
    echo "FAIL (no workflow file)"
    ((FAIL++))
fi

# --- Objective 4: Build job ---
echo -n "[4/7] Pipeline has build job (Docker): "
if [[ -f "${WORKFLOW}" ]]; then
    has_build=$(grep -c "build" "${WORKFLOW}" || echo 0)
    has_docker=$(grep -ciE "docker|container" "${WORKFLOW}" || echo 0)
    if [[ ${has_build} -gt 0 && ${has_docker} -gt 0 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (build=${has_build}, docker=${has_docker})"
        ((FAIL++))
    fi
else
    echo "FAIL (no workflow file)"
    ((FAIL++))
fi

# --- Objective 5: Scan job with Trivy ---
echo -n "[5/7] Pipeline has scan job (Trivy or equivalent): "
if [[ -f "${WORKFLOW}" ]]; then
    has_scan=$(grep -ciE "scan|trivy|security|vulnerability" "${WORKFLOW}" || echo 0)
    if [[ ${has_scan} -gt 0 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (no scan/trivy/security step found)"
        ((FAIL++))
    fi
else
    echo "FAIL (no workflow file)"
    ((FAIL++))
fi

# --- Objective 6: Deploy job with main-branch condition ---
echo -n "[6/7] Deploy job runs only on main branch: "
if [[ -f "${WORKFLOW}" ]]; then
    has_deploy=$(grep -c "deploy" "${WORKFLOW}" || echo 0)
    has_main_cond=$(grep -cE "refs/heads/main|github.ref.*main" "${WORKFLOW}" || echo 0)
    if [[ ${has_deploy} -gt 0 && ${has_main_cond} -gt 0 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (deploy=${has_deploy}, main-condition=${has_main_cond})"
        ((FAIL++))
    fi
else
    echo "FAIL (no workflow file)"
    ((FAIL++))
fi

# --- Objective 7: Job dependency chains (needs:) ---
echo -n "[7/7] Jobs use dependency chains (needs:): "
if [[ -f "${WORKFLOW}" ]]; then
    needs_count=$(grep -c "needs:" "${WORKFLOW}" || echo 0)
    if [[ ${needs_count} -ge 3 ]]; then
        echo "PASS (${needs_count} dependency declarations)"
        ((PASS++))
    else
        echo "FAIL (${needs_count} needs: — expected at least 3)"
        ((FAIL++))
    fi
else
    echo "FAIL (no workflow file)"
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
