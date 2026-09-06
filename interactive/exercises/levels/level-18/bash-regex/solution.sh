#!/bin/bash
# This script extracts IP addresses from log entries

LOG="Connection from 192.168.1.100 accepted
Request from 10.0.0.5 denied
Ping from 172.16.0.1 timeout
Normal log entry without IP
Another entry from 8.8.8.8 resolved"

# Fixed: Added -E flag for extended regex (supports +)
COUNT=$(echo "$LOG" | grep -cE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

echo "SUCCESS: Found $COUNT lines with IP addresses"
