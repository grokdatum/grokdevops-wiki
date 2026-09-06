#!/bin/bash
# This script compares two sorted lists and counts differences

LIST_A="alpha
bravo
charlie
delta"

LIST_B="alpha
charlie
delta
echo"

ADDED=0
REMOVED=0

# Fixed: Use process substitution to feed the while loop without subshell
while read line; do
    if [[ "$line" == ">"* ]]; then
        ADDED=$((ADDED + 1))
    elif [[ "$line" == "<"* ]]; then
        REMOVED=$((REMOVED + 1))
    fi
done < <(diff <(echo "$LIST_A") <(echo "$LIST_B") | grep "^[<>]")

echo "SUCCESS: Changes detected - $ADDED added, $REMOVED removed"
