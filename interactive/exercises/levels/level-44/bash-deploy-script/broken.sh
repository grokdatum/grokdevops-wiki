#!/bin/bash
# Deployment script that should validate each step

deploy() {
    echo "=== Deployment Starting ==="

    # Step 1: Pull latest code (simulated)
    echo "Pulling latest code..."
    PULL_RESULT=0

    # Step 2: Run migrations (simulated - fails!)
    echo "Running database migrations..."
    MIGRATION_RESULT=1  # Migration failed!

    # BUG: Not checking MIGRATION_RESULT before continuing
    echo "Starting application..."
    APP_RESULT=0

    echo "Deployment complete"
}

deploy

# Check if deployment was actually safe
if [ "$MIGRATION_RESULT" -eq 0 ]; then
    echo "SUCCESS: All deployment steps passed"
else
    echo "FAIL: Deployed with failed migrations!"
fi
