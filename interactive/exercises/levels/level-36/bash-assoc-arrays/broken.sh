#!/bin/bash
# This script stores service configurations using key-value pairs

# BUG: Using regular array instead of associative array (missing declare -A)
declare -a SERVICE_PORTS

SERVICE_PORTS[web]=8080
SERVICE_PORTS[api]=3000
SERVICE_PORTS[db]=5432

# Try to access by key
WEB_PORT="${SERVICE_PORTS[web]}"
API_PORT="${SERVICE_PORTS[api]}"
DB_PORT="${SERVICE_PORTS[db]}"

if [ "$WEB_PORT" = "8080" ] && [ "$API_PORT" = "3000" ] && [ "$DB_PORT" = "5432" ]; then
    echo "SUCCESS: Service ports - web:$WEB_PORT api:$API_PORT db:$DB_PORT"
else
    echo "FAIL: Could not retrieve ports by name (web:$WEB_PORT api:$API_PORT db:$DB_PORT)"
fi
