#!/bin/bash
# This script reads a config and counts active services

ACTIVE_COUNT=0

# Fixed: Use process substitution or here-string to avoid subshell
while read line; do
    STATUS=$(echo "$line" | cut -d: -f2)
    if [ "$STATUS" = "active" ]; then
        ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
    fi
done <<< "$(echo -e "nginx:active\nredis:active\npostgres:inactive\nrabbit:active")"

echo "SUCCESS: Active services: $ACTIVE_COUNT"
