#!/bin/bash
# This script dynamically reads config values using variable names

CONFIG_DB_HOST="db.example.com"
CONFIG_DB_PORT="5432"
CONFIG_APP_PORT="8080"

get_config() {
    local key="$1"
    local var_name="CONFIG_${key}"

    # Fixed: Use indirect variable expansion instead of eval (safer)
    echo "${!var_name}"
}

DB_HOST=$(get_config "DB_HOST")
DB_PORT=$(get_config "DB_PORT")
APP_PORT=$(get_config "APP_PORT")

if [ "$DB_HOST" = "db.example.com" ] && [ "$DB_PORT" = "5432" ] && [ "$APP_PORT" = "8080" ]; then
    echo "SUCCESS: Config loaded - DB=$DB_HOST:$DB_PORT APP_PORT=$APP_PORT"
else
    echo "FAIL: Config values wrong - DB=$DB_HOST:$DB_PORT APP_PORT=$APP_PORT"
fi
