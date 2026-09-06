#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-terraform"

echo "=== Terraform IaC Lab — Teardown ==="

# Use terraform destroy if possible
if [[ -d "${LAB_ROOT}/.terraform" && -f "${LAB_ROOT}/terraform.tfstate" ]]; then
    echo "Running terraform destroy..."
    (cd "${LAB_ROOT}" && terraform destroy -auto-approve 2>/dev/null) || true
fi

# Manual cleanup of any leftover containers
for c in lab-tf-web lab-tf-api lab-tf-db; do
    docker rm -f "${c}" 2>/dev/null || true
done
docker network rm lab-tf-network 2>/dev/null || true

if [[ -d "${LAB_ROOT}" ]]; then
    echo "Removing ${LAB_ROOT}..."
    rm -rf "${LAB_ROOT}"
fi

echo "=== Teardown Complete ==="
