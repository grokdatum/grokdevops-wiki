#!/bin/bash
# This script parses command-line options for a deployment tool

ENVIRONMENT=""
VERSION=""
VERBOSE=false

# BUG: Missing colon after e and v - they need arguments but getopts thinks they're flags
while getopts "ev" opt; do
    case $opt in
        e) ENVIRONMENT="$OPTARG" ;;
        v) VERSION="$OPTARG" ;;
        *) echo "Usage: $0 -e <env> -v <version>" ;;
    esac
done

if [ -n "$ENVIRONMENT" ] && [ -n "$VERSION" ]; then
    echo "SUCCESS: Deploying version $VERSION to $ENVIRONMENT"
else
    echo "FAIL: Missing environment ($ENVIRONMENT) or version ($VERSION)"
fi
