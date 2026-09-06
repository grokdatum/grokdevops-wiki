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

    # Fixed: Check migration result before continuing
    if [ "$MIGRATION_RESULT" -ne 0 ]; then
        echo "ERROR: Migrations failed, aborting deployment"
        return 1
    fi

    echo "Starting application..."
    APP_RESULT=0

    echo "Deployment complete"
}

deploy

# Check if deployment was actually safe
if [ $? -eq 0 ]; then
    echo "FAIL: Deployed with failed migrations!"
else
    echo "SUCCESS: Deployment correctly aborted on migration failure"
fi
