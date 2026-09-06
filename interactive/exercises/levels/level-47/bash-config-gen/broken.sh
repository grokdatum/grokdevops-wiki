#!/bin/bash
# Config generator using template substitution

DB_HOST="db.production.local"
DB_PORT="5432"
APP_NAME="webservice"

# BUG: Single-quoted heredoc prevents variable expansion in template
CONFIG=$(cat << 'TEMPLATE'
database:
  host: $DB_HOST
  port: $DB_PORT
application:
  name: $APP_NAME
TEMPLATE
)

if echo "$CONFIG" | grep -q "db.production.local"; then
    echo "SUCCESS: Config generated with substituted values"
    echo "$CONFIG"
else
    echo "FAIL: Variables not substituted in config"
    echo "$CONFIG"
fi
