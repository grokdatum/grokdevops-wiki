#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-terraform"
PASS=0
FAIL=0
TOTAL=7

echo "=== Terraform IaC Lab — Grading ==="
echo ""

# --- Objective 1: Terraform initialized ---
echo -n "[1/7] Terraform initialized (.terraform exists): "
if [[ -d "${LAB_ROOT}/.terraform" ]]; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (run 'terraform init' in ${LAB_ROOT})"
    ((FAIL++))
fi

# --- Objective 2: Module directory has real code ---
echo -n "[2/7] Module app-stack has resource definitions: "
module_main="${LAB_ROOT}/modules/app-stack/main.tf"
if [[ -f "${module_main}" ]]; then
    resource_count=$(grep -c '^resource ' "${module_main}" || echo 0)
    if [[ ${resource_count} -ge 3 ]]; then
        echo "PASS (${resource_count} resources defined)"
        ((PASS++))
    else
        echo "FAIL (${resource_count} resources — need at least 3)"
        ((FAIL++))
    fi
else
    echo "FAIL (module main.tf not found)"
    ((FAIL++))
fi

# --- Objective 3: Variables defined in module ---
echo -n "[3/7] Module uses variables: "
mod_vars="${LAB_ROOT}/modules/app-stack/variables.tf"
if [[ -f "${mod_vars}" ]]; then
    var_count=$(grep -c '^variable ' "${mod_vars}" || echo 0)
    if [[ ${var_count} -ge 2 ]]; then
        echo "PASS (${var_count} variables)"
        ((PASS++))
    else
        echo "FAIL (${var_count} variables — need at least 2)"
        ((FAIL++))
    fi
else
    echo "FAIL (module variables.tf not found)"
    ((FAIL++))
fi

# --- Objective 4: Outputs defined ---
echo -n "[4/7] Outputs defined (root or module): "
output_count=0
for f in "${LAB_ROOT}/outputs.tf" "${LAB_ROOT}/modules/app-stack/outputs.tf"; do
    if [[ -f "${f}" ]]; then
        c=$(grep -c '^output ' "${f}" || echo 0)
        output_count=$((output_count + c))
    fi
done
if [[ ${output_count} -ge 2 ]]; then
    echo "PASS (${output_count} outputs)"
    ((PASS++))
else
    echo "FAIL (${output_count} outputs — need at least 2)"
    ((FAIL++))
fi

# --- Objective 5: terraform plan succeeds ---
echo -n "[5/7] terraform plan succeeds: "
if [[ -d "${LAB_ROOT}/.terraform" ]]; then
    plan_output=$(cd "${LAB_ROOT}" && terraform plan -no-color 2>&1) || true
    if echo "${plan_output}" | grep -qE "Plan:|No changes"; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (plan errors detected)"
        ((FAIL++))
    fi
else
    echo "FAIL (not initialized)"
    ((FAIL++))
fi

# --- Objective 6: State file exists (apply was run) ---
echo -n "[6/7] terraform apply completed (state file exists): "
if [[ -f "${LAB_ROOT}/terraform.tfstate" ]]; then
    resource_in_state=$(grep -c '"type"' "${LAB_ROOT}/terraform.tfstate" || echo 0)
    if [[ ${resource_in_state} -gt 0 ]]; then
        echo "PASS (${resource_in_state} resource entries in state)"
        ((PASS++))
    else
        echo "FAIL (state file empty)"
        ((FAIL++))
    fi
else
    echo "FAIL (no terraform.tfstate — run 'terraform apply')"
    ((FAIL++))
fi

# --- Objective 7: Containers are running ---
echo -n "[7/7] All three containers running: "
running=0
for pattern in "lab-tf-web\|web" "lab-tf-api\|api" "lab-tf-db\|db\|redis"; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qiE "${pattern}"; then
        ((running++))
    fi
done
if [[ ${running} -ge 3 ]]; then
    echo "PASS (${running} containers running)"
    ((PASS++))
else
    echo "FAIL (${running}/3 containers found)"
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
