#!/bin/bash
# This script finds PIDs of running bash processes

# Simulate ps output for testing
PS_OUTPUT="  PID TTY          TIME CMD
    1 ?        00:00:00 init
   42 pts/0    00:00:00 bash
  100 pts/0    00:00:01 bash
  200 pts/0    00:00:00 python"

# Fixed: Extract field $1 (PID) instead of $3 (TIME)
PIDS=$(echo "$PS_OUTPUT" | grep "bash" | awk '{print $1}')

echo "Bash PIDs: $PIDS"
COUNT=$(echo "$PIDS" | wc -w)
echo "SUCCESS: Found $COUNT bash processes"
