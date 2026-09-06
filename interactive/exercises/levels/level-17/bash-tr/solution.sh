#!/bin/bash
# This script normalizes environment names to uppercase

ENVS="production staging development testing"

# Fixed: Convert lowercase to uppercase
NORMALIZED=$(echo "$ENVS" | tr 'a-z' 'A-Z')

echo "SUCCESS: Environments: $NORMALIZED"
