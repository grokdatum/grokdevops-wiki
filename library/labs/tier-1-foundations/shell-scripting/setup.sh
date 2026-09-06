#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-shell"

echo "=== Shell Scripting Lab Setup ==="
echo "Creating service simulation at ${LAB_ROOT}..."

# Idempotent cleanup
rm -rf "${LAB_ROOT}"
mkdir -p "${LAB_ROOT}/services"

# Define the 5 services
SERVICES=("web-server" "api-gateway" "redis-cache" "postgresql" "rabbitmq")

# Create health endpoints for each service
for svc in "${SERVICES[@]}"; do
    mkdir -p "${LAB_ROOT}/services/${svc}"
    echo "ok" > "${LAB_ROOT}/services/${svc}/health"
done

# Break 2 services so the student's script can detect them
echo "connection refused" > "${LAB_ROOT}/services/redis-cache/health"
rm -f "${LAB_ROOT}/services/rabbitmq/health"

# Create the service list file for reference
printf '%s\n' "${SERVICES[@]}" > "${LAB_ROOT}/services/service-list.txt"

# Create a template for the student
cat > "${LAB_ROOT}/monitor.sh" <<'TEMPLATE'
#!/usr/bin/env bash
# TODO: Implement this monitoring script
#
# Requirements:
#   1. Check each service in /tmp/lab-shell/services/*/health
#   2. Log results with timestamps to /tmp/lab-shell/logs/monitor.log
#   3. Write down services to /tmp/lab-shell/alerts/active.txt
#   4. Clear alerts for recovered services
#   5. Exit 0 if all healthy, 1 if any down
#   6. Create directories if they don't exist
#   7. Be idempotent
#
# A service is "healthy" if its health file exists and contains "ok".
# A service is "down" if the file is missing or contains anything other than "ok".

echo "TODO: implement monitoring"
exit 1
TEMPLATE
chmod +x "${LAB_ROOT}/monitor.sh"

echo ""
echo "=== Setup Complete ==="
echo "Lab environment at: ${LAB_ROOT}"
echo ""
echo "Services (check ${LAB_ROOT}/services/):"
for svc in "${SERVICES[@]}"; do
    if [[ -f "${LAB_ROOT}/services/${svc}/health" ]] && [[ "$(cat "${LAB_ROOT}/services/${svc}/health")" == "ok" ]]; then
        echo "  [OK]   ${svc}"
    else
        echo "  [DOWN] ${svc}"
    fi
done
echo ""
echo "Your mission:"
echo "  Edit ${LAB_ROOT}/monitor.sh to implement the monitoring script."
echo "  Run ./grade.sh when done."
