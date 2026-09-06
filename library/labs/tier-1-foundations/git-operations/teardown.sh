#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-git-operations"

echo "=== Git Operations Lab — Teardown ==="

if [[ -d "${LAB_ROOT}" ]]; then
    echo "Removing ${LAB_ROOT}..."
    rm -rf "${LAB_ROOT}"
fi

rm -f /tmp/lab-git-ops-detached-sha /tmp/lab-git-ops-original-head /tmp/lab-git-ops-secret-sha

echo "=== Teardown Complete ==="
