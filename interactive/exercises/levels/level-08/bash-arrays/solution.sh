#!/bin/bash
# This script lists all available services

SERVICES=("nginx" "redis" "postgres" "rabbitmq")

# Fixed: Use ${SERVICES[*]} inside one quoted field and ${#SERVICES[@]} for count
printf 'Available services: %s\n' "${SERVICES[*]}"
echo "Total count: ${#SERVICES[@]}"
echo "SUCCESS: Listed all ${#SERVICES[@]} services"
