#!/bin/bash
# This script generates a config file with dynamic values

APP_NAME="myapp"
APP_PORT=8080
APP_ENV="production"

# Fixed: Unquoted heredoc delimiter allows variable expansion
CONFIG=$(cat << ENDCONFIG
server {
    application: $APP_NAME
    port: $APP_PORT
    environment: $APP_ENV
    status: active
}
ENDCONFIG
)

echo "$CONFIG"

if echo "$CONFIG" | grep -q "application: myapp"; then
    echo "SUCCESS: Config generated with correct values"
else
    echo "FAIL: Variables were not expanded in config"
fi
