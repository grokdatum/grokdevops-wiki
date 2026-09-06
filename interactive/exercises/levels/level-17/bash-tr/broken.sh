#!/bin/bash
# This script normalizes environment names to uppercase

ENVS="production staging development testing"

# BUG: Arguments are swapped - converting uppercase to lowercase instead
NORMALIZED=$(echo "$ENVS" | tr 'A-Z' 'a-z')

echo "SUCCESS: Environments: $NORMALIZED"
