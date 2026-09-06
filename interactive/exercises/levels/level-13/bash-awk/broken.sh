#!/bin/bash
# This script extracts usernames from a CSV file

CSV_DATA="john,admin,active
jane,user,active
bob,admin,inactive"

# BUG: AWK defaults to whitespace separator, not comma
# Without -F',' the entire line is field $1
USERS=$(echo "$CSV_DATA" | awk '{print $1}')

echo "Users:"
echo "$USERS"

# Verify output is clean (just names, no commas)
if echo "$USERS" | grep -q ","; then
    echo "FAIL: Output contains commas - fields not split correctly"
else
    echo "SUCCESS: Users extracted cleanly"
fi
