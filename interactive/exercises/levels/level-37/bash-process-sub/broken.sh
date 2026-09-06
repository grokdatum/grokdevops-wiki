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

# BUG: Piping into while loop creates subshell, ADDED/REMOVED changes are lost
diff <(echo "$LIST_A") <(echo "$LIST_B") | grep "^[<>]" | while read line; do
    if [[ "$line" == ">"* ]]; then
        ADDED=$((ADDED + 1))
    elif [[ "$line" == "<"* ]]; then
        REMOVED=$((REMOVED + 1))
    fi
done

echo "SUCCESS: Changes detected - $ADDED added, $REMOVED removed"
