#!/bin/bash
# This script calculates total disk space needed for a deployment

BASE_SIZE=500
REPLICAS=3
OVERHEAD=100

# BUG: Using expr wrong - missing backticks/syntax and incorrect usage
TOTAL=expr $BASE_SIZE * $REPLICAS + $OVERHEAD

echo "Base size: ${BASE_SIZE}MB"
echo "Replicas: ${REPLICAS}"
echo "Overhead: ${OVERHEAD}MB"
echo "SUCCESS: Total space needed: ${TOTAL}MB"
