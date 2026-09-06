#!/bin/bash
# Pre-commit hook that checks for debug statements in Python files

# Simulated staged files
STAGED_FILES="app/main.py
app/utils.py
app/test_main.py
README.md
config.yaml"

# BUG: Pattern "*.js" doesn't match Python files - should be "*.py"
MATCHED=$(echo "$STAGED_FILES" | grep '\.js$')

if [ -z "$MATCHED" ]; then
    echo "No matching files found to check"
else
    HAS_DEBUG=false
    echo "$MATCHED" | while read file; do
        echo "Checking: $file"
    done
    echo "SUCCESS: Checked Python files for debug statements"
fi
