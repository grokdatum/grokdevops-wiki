#!/bin/bash
# This script lists all available services

SERVICES=("nginx" "redis" "postgres" "rabbitmq")

# BUG: Missing @ - only prints first element instead of all
echo "Available services: ${SERVICES}"
echo "Total count: ${#SERVICES}"
echo "SUCCESS: Listed all ${#SERVICES[@]} services"
