#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-shell"

echo "=== Shell Scripting Lab — Teardown ==="

if [[ -d "${LAB_ROOT}" ]]; then
    echo "Removing ${LAB_ROOT}..."
    rm -rf "${LAB_ROOT}"
fi

echo "=== Teardown Complete ==="
