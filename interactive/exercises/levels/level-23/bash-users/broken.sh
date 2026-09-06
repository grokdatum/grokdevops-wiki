#!/bin/bash
# This script simulates user creation and validates the command

USERNAME="deployer"

# BUG: Missing -m flag to create home directory
USERADD_CMD="useradd $USERNAME"

# Validate the command has the right flags
if echo "$USERADD_CMD" | grep -q "\-m"; then
    echo "SUCCESS: Command will create home directory for $USERNAME"
    echo "Command: $USERADD_CMD"
else
    echo "FAIL: Command missing -m flag, no home directory will be created"
    echo "Command: $USERADD_CMD"
fi
