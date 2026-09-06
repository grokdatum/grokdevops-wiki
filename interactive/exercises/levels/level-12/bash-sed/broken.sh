#!/bin/bash
# This script replaces all tabs with spaces in a config

INPUT="host:port	host:port	host:port"

# BUG: Missing 'g' flag - only replaces first tab on each line
OUTPUT=$(echo "$INPUT" | sed 's/\t/ /')

echo "SUCCESS: $OUTPUT"
