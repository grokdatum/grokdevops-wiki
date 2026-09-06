#!/bin/bash
# Template engine for generating nginx config

SERVER_NAME="app.example.com"
PROXY_PORT="8080"

# Fixed: Escape the dollar signs that should be literal nginx variables
NGINX_CONFIG="server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://localhost:$PROXY_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}"

# Check if the nginx variables survived (they should be literal $host, $remote_addr)
if echo "$NGINX_CONFIG" | grep -q '$host' && echo "$NGINX_CONFIG" | grep -q '$remote_addr'; then
    echo "SUCCESS: Nginx config has correct variable syntax"
else
    echo "FAIL: Nginx variables were incorrectly expanded"
fi

echo "$NGINX_CONFIG"
