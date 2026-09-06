#!/bin/bash
# This script counts from 1 to 5

count=1
result=""

while [ "$count" -le 5 ]; do
    result="${result}${count} "
    # BUG: Missing counter increment - infinite loop!
done

echo "SUCCESS: Counted: ${result}"
