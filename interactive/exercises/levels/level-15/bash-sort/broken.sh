#!/bin/bash
# This script sorts server response times and finds the slowest

TIMES="120
5
45
1000
8
300
22"

# BUG: Missing -n flag causes lexicographic sort (5 > 45 > 300)
SORTED=$(echo "$TIMES" | sort)
SLOWEST=$(echo "$SORTED" | tail -1)

echo "Sorted times: $(echo "$SORTED" | tr '\n' ' ')"
echo "SUCCESS: Slowest response: ${SLOWEST}ms"
