#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-linux-triage"
PASS=0
FAIL=0
TOTAL=5

echo "=== Linux Triage Lab — Grading ==="
echo ""

# --- Objective 1: Disk space freed ---
echo -n "[1/5] Disk space freed (< 100 MB in /var/log): "
if [[ -d "${LAB_ROOT}/var/log" ]]; then
    log_size_kb=$(du -s "${LAB_ROOT}/var/log" 2>/dev/null | awk '{print $1}')
    log_size_mb=$((log_size_kb / 1024))
    if [[ ${log_size_mb} -lt 100 ]]; then
        echo "PASS (${log_size_mb} MB remaining)"
        ((PASS++))
    else
        echo "FAIL (${log_size_mb} MB — need below 100 MB)"
        ((FAIL++))
    fi
else
    echo "FAIL (log directory not found)"
    ((FAIL++))
fi

# --- Objective 2: Zombie process killed ---
echo -n "[2/5] Zombie process eliminated: "
if [[ -f "${LAB_ROOT}/proc/zombie-parent.pid" ]]; then
    parent_pid=$(cat "${LAB_ROOT}/proc/zombie-parent.pid")
    if kill -0 "${parent_pid}" 2>/dev/null; then
        echo "FAIL (parent PID ${parent_pid} still running)"
        ((FAIL++))
    else
        echo "PASS (parent process terminated)"
        ((PASS++))
    fi
else
    echo "PASS (PID file cleaned up)"
    ((PASS++))
fi

# --- Objective 3: Cron job fixed ---
echo -n "[3/5] Cron job syntax valid: "
cron_file="${LAB_ROOT}/etc/cron.d/broken-task"
if [[ -f "${cron_file}" ]]; then
    # Check: must have exactly 6 fields (5 schedule + 1 command), no extra
    # Filter out comments and blank lines
    valid=true
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue
        field_count=$(echo "${line}" | awk '{print NF}')
        if [[ ${field_count} -lt 6 ]]; then
            valid=false
        fi
        # Check that no field looks like "999.999" (invalid IP leftover)
        if echo "${line}" | grep -q "nonexistent"; then
            valid=false
        fi
        # Must not have 7+ fields where first 6 are all cron-like
        first_six=$(echo "${line}" | awk '{print $1,$2,$3,$4,$5,$6}')
        if echo "${first_six}" | grep -qE '^\*.*\*.*\*.*\*.*\*.*\*'; then
            valid=false
        fi
    done < "${cron_file}"
    if ${valid}; then
        echo "PASS"
        ((PASS++))
    else
        echo "FAIL (syntax still broken — check field count and command path)"
        ((FAIL++))
    fi
else
    echo "FAIL (cron file not found)"
    ((FAIL++))
fi

# --- Objective 4: File permissions fixed ---
echo -n "[4/5] Config directory permissions (750, root-owned): "
config_dir="${LAB_ROOT}/opt/app/config"
if [[ -d "${config_dir}" ]]; then
    perms=$(stat -c '%a' "${config_dir}" 2>/dev/null)
    owner=$(stat -c '%U' "${config_dir}" 2>/dev/null)
    if [[ "${perms}" == "750" && "${owner}" == "root" ]]; then
        echo "PASS (mode ${perms}, owner ${owner})"
        ((PASS++))
    else
        echo "FAIL (mode=${perms}, owner=${owner} — need 750/root)"
        ((FAIL++))
    fi
else
    echo "FAIL (config directory not found)"
    ((FAIL++))
fi

# --- Objective 5: DNS resolution fixed ---
echo -n "[5/5] DNS configuration valid: "
resolv_file="${LAB_ROOT}/etc/resolv.conf"
if [[ -f "${resolv_file}" ]]; then
    # Must have at least one valid nameserver (matches IP pattern)
    valid_ns=$(grep -E '^nameserver\s+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "${resolv_file}" | head -1)
    if [[ -n "${valid_ns}" ]]; then
        # Check it's not the bogus 999.999.999.999
        ip=$(echo "${valid_ns}" | awk '{print $2}')
        if [[ "${ip}" != "999.999.999.999" ]]; then
            echo "PASS (nameserver ${ip})"
            ((PASS++))
        else
            echo "FAIL (still using bogus nameserver)"
            ((FAIL++))
        fi
    else
        echo "FAIL (no valid nameserver line found)"
        ((FAIL++))
    fi
else
    echo "FAIL (resolv.conf not found)"
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
