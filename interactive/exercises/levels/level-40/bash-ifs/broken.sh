#!/bin/bash
# This script parses CSV data using IFS

CSV_LINE="John Doe,Engineering,Senior Developer,95000"

# BUG: IFS not set to comma - defaults to whitespace, splitting on spaces too
IFS=' '
read -r name dept title salary <<< "$CSV_LINE"

if [ "$name" = "John Doe" ] && [ "$dept" = "Engineering" ] && [ "$salary" = "95000" ]; then
    echo "SUCCESS: Parsed - Name: $name, Dept: $dept, Title: $title, Salary: $salary"
else
    echo "FAIL: Parse error - Name: '$name', Dept: '$dept', Title: '$title', Salary: '$salary'"
fi
