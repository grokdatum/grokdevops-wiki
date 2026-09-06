#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-container-basics"
IMAGE_NAME="lab-container-basics:grading"
CONTAINER_NAME="lab-container-basics-test"

echo "=== Container Basics Lab — Teardown ==="

# Stop and remove any running container
docker rm -f "${CONTAINER_NAME}" 2>/dev/null && echo "Removed container ${CONTAINER_NAME}" || true

# Remove the image
docker rmi "${IMAGE_NAME}" 2>/dev/null && echo "Removed image ${IMAGE_NAME}" || true

# Remove lab directory
if [[ -d "${LAB_ROOT}" ]]; then
    echo "Removing ${LAB_ROOT}..."
    rm -rf "${LAB_ROOT}"
fi

echo "=== Teardown Complete ==="
