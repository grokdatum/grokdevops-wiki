#!/bin/bash
# This script parses command-line options for a deployment tool

ENVIRONMENT=""
VERSION=""
VERBOSE=false

# Fixed: Added colons after e and v to indicate they take arguments
while getopts "e:v:" opt; do
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
