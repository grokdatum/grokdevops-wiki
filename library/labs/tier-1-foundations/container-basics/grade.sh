#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-container-basics"
PASS=0
FAIL=0
TOTAL=7
IMAGE_NAME="lab-container-basics:grading"
CONTAINER_NAME="lab-container-basics-test"

echo "=== Container Basics Lab — Grading ==="
echo ""

# Clean up any previous grading container
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Build the image
echo "Building image from ${LAB_ROOT}..."
if ! docker build -t "${IMAGE_NAME}" "${LAB_ROOT}" > /tmp/lab-container-build.log 2>&1; then
    echo "FATAL: Docker build failed. Cannot grade."
    cat /tmp/lab-container-build.log
    exit 1
fi
echo ""

# --- Objective 1: Multi-stage build ---
echo -n "[1/7] Multi-stage Dockerfile: "
stage_count=$(grep -ci '^FROM' "${LAB_ROOT}/Dockerfile" 2>/dev/null || echo 0)
if [[ ${stage_count} -ge 2 ]]; then
    echo "PASS (${stage_count} stages)"
    ((PASS++))
else
    echo "FAIL (found ${stage_count} FROM — need at least 2)"
    ((FAIL++))
fi

# --- Objective 2: Image size under 200 MB ---
echo -n "[2/7] Image size under 200 MB: "
image_size_bytes=$(docker image inspect "${IMAGE_NAME}" --format='{{.Size}}' 2>/dev/null || echo 0)
image_size_mb=$((image_size_bytes / 1024 / 1024))
if [[ ${image_size_mb} -lt 200 ]]; then
    echo "PASS (${image_size_mb} MB)"
    ((PASS++))
else
    echo "FAIL (${image_size_mb} MB — must be under 200 MB)"
    ((FAIL++))
fi

# --- Objective 3: Non-root user ---
echo -n "[3/7] Runs as non-root: "
run_user=$(docker run --rm "${IMAGE_NAME}" whoami 2>/dev/null || echo "root")
if [[ "${run_user}" != "root" ]]; then
    echo "PASS (user: ${run_user})"
    ((PASS++))
else
    echo "FAIL (running as root)"
    ((FAIL++))
fi

# --- Objective 4: Layer caching (package.json before source) ---
echo -n "[4/7] Layer caching (package.json copied before source): "
dockerfile="${LAB_ROOT}/Dockerfile"
if grep -qE 'COPY.*package.*\.json' "${dockerfile}" 2>/dev/null; then
    pkg_line=$(grep -n 'COPY.*package.*\.json' "${dockerfile}" | head -1 | cut -d: -f1)
    src_line=$(grep -n 'COPY.*\.\s' "${dockerfile}" | tail -1 | cut -d: -f1)
    if [[ -n "${pkg_line}" && -n "${src_line}" && ${pkg_line} -lt ${src_line} ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (package.json should be copied before application source)"
        ((FAIL++))
    fi
else
    echo "FAIL (no separate COPY for package.json found)"
    ((FAIL++))
fi

# --- Objective 5: .dockerignore exists ---
echo -n "[5/7] .dockerignore excludes .git and node_modules: "
ignore_file="${LAB_ROOT}/.dockerignore"
if [[ -f "${ignore_file}" ]]; then
    has_git=$(grep -c '\.git' "${ignore_file}" || echo 0)
    has_nm=$(grep -c 'node_modules' "${ignore_file}" || echo 0)
    if [[ ${has_git} -gt 0 && ${has_nm} -gt 0 ]]; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (.dockerignore missing .git or node_modules)"
        ((FAIL++))
    fi
else
    echo "FAIL (.dockerignore not found)"
    ((FAIL++))
fi

# --- Objective 6: Health check defined ---
echo -n "[6/7] HEALTHCHECK in Dockerfile: "
if grep -qi 'HEALTHCHECK' "${dockerfile}" 2>/dev/null; then
    echo "PASS"
    ((PASS++))
else
    echo "FAIL (no HEALTHCHECK instruction found)"
    ((FAIL++))
fi

# --- Objective 7: Container responds on port 3000 ---
echo -n "[7/7] Container responds on port 3000: "
docker run -d --name "${CONTAINER_NAME}" -p 13000:3000 "${IMAGE_NAME}" > /dev/null 2>&1
sleep 3
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:13000/ 2>/dev/null || echo "000")
docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1 || true
if [[ "${response}" == "200" ]]; then
    echo "PASS (HTTP ${response})"
    ((PASS++))
else
    echo "FAIL (HTTP ${response} — expected 200)"
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
