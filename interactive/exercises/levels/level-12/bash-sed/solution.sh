#!/bin/bash
# This script replaces all tabs with spaces in a config

INPUT="host:port	host:port	host:port"

# Fixed: Added 'g' flag to replace all occurrences
OUTPUT=$(echo "$INPUT" | sed 's/\t/ /g')

echo "SUCCESS: $OUTPUT"
