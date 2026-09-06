#!/bin/bash
# This script uses a function to validate a port number

# BUG: Function is called before it is defined
RESULT=$(validate_port 8080)
echo "$RESULT"

validate_port() {
    local port=$1
    if [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        echo "SUCCESS: Port $port is valid"
    else
        echo "FAIL: Port $port is out of range"
    fi
}
