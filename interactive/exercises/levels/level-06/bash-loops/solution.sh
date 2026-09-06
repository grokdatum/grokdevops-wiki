#!/bin/bash
# This script counts from 1 to 5

count=1
result=""

while [ "$count" -le 5 ]; do
    result="${result}${count} "
    # Fixed: Increment counter to avoid infinite loop
    count=$((count + 1))
done

echo "SUCCESS: Counted: ${result}"
