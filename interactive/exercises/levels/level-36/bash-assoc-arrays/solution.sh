#!/bin/bash
# This script stores service configurations using key-value pairs

# Fixed: Use declare -A for associative (key-value) arrays
declare -A SERVICE_PORTS

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
