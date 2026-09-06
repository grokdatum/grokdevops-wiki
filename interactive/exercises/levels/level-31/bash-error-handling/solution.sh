#!/bin/bash
# This script deploys an application and should abort on any error

# Fixed: set -e causes script to exit on any command failure
set -e

deploy_step() {
    local step="$1"
    local will_fail="$2"

    if [ "$will_fail" = "true" ]; then
        echo "Step $step: FAILED"
        return 1
    fi
    echo "Step $step: OK"
    return 0
}

deploy_step "Download artifacts" "false"
deploy_step "Run tests" "true"
# This should NOT execute if the previous step failed
deploy_step "Deploy to production" "false"

# Check if we got here (we shouldn't have with set -e)
if [ $? -eq 0 ]; then
    echo "FAIL: Script continued after error (deployed broken code!)"
else
    echo "SUCCESS: Script aborted on error"
fi
