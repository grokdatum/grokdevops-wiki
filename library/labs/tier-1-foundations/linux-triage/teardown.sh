#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-linux-triage"

echo "=== Linux Triage Lab — Teardown ==="

# Kill zombie parent if still running
if [[ -f "${LAB_ROOT}/proc/zombie-parent.pid" ]]; then
    pid=$(cat "${LAB_ROOT}/proc/zombie-parent.pid")
    if kill -0 "${pid}" 2>/dev/null; then
        echo "Killing zombie parent process (PID ${pid})..."
        kill -9 "${pid}" 2>/dev/null || true
    fi
fi

# Remove lab directory
if [[ -d "${LAB_ROOT}" ]]; then
    echo "Removing ${LAB_ROOT}..."
    rm -rf "${LAB_ROOT}"
    echo "Lab environment cleaned up."
else
    echo "Nothing to clean up (${LAB_ROOT} does not exist)."
fi

echo "=== Teardown Complete ==="
