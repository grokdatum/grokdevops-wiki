#!/bin/bash
# This script extracts IP addresses from a colon-separated config

CONFIG="webserver:192.168.1.10:8080
database:192.168.1.20:5432
cache:192.168.1.30:6379"

# Fixed: Use colon delimiter (-d':') and field 2 (-f2) for the IP
echo "$CONFIG" | cut -d':' -f2 | while read ip; do
    echo "IP: $ip"
done
echo "SUCCESS: IPs extracted"
