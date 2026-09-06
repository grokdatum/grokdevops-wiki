#!/bin/bash
# This script sorts server response times and finds the slowest

TIMES="120
5
45
1000
8
300
22"

# Fixed: Use -n for numeric sort
SORTED=$(echo "$TIMES" | sort -n)
SLOWEST=$(echo "$SORTED" | tail -1)

echo "Sorted times: $(echo "$SORTED" | tr '\n' ' ')"
echo "SUCCESS: Slowest response: ${SLOWEST}ms"
