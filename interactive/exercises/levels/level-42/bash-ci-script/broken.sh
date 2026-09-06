#!/bin/bash
# CI/CD pipeline script

# BUG: Missing set -e - script continues even when steps fail

echo "=== CI Pipeline ==="

echo "Step 1: Installing dependencies..."
echo "Dependencies installed"

echo "Step 2: Running linter..."
echo "Linter passed"

echo "Step 3: Running tests..."
# Simulate test failure
false
echo "Tests completed"

echo "Step 4: Building artifact..."
echo "Build complete"

echo "Step 5: Deploying..."
echo "FAIL: Deployed despite test failures!"
