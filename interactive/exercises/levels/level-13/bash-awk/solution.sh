#!/bin/bash
# This script extracts usernames from a CSV file

CSV_DATA="john,admin,active
jane,user,active
bob,admin,inactive"

# Fixed: Set field separator to comma with -F','
USERS=$(echo "$CSV_DATA" | awk -F',' '{print $1}')

echo "Users:"
echo "$USERS"

# Verify output is clean (just names, no commas)
if echo "$USERS" | grep -q ","; then
    echo "FAIL: Output contains commas - fields not split correctly"
else
    echo "SUCCESS: Users extracted cleanly"
fi
