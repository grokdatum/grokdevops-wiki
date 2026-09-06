#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-git-operations"

echo "=== Git Operations Lab Setup ==="
echo "Creating git disaster repo at ${LAB_ROOT}..."

# Idempotent cleanup
rm -rf "${LAB_ROOT}"
mkdir -p "${LAB_ROOT}"
cd "${LAB_ROOT}"

# Initialize repo
git init -q
git config user.email "lab@example.com"
git config user.name "Lab User"

# --- Build base history ---
echo "version 1" > app.txt
git add app.txt && git commit -q -m "Initial commit"

echo "version 2" > app.txt
git add app.txt && git commit -q -m "Add feature A"

echo "version 3" > app.txt
git add app.txt && git commit -q -m "Add feature B"

echo "version 4" > app.txt
git add app.txt && git commit -q -m "Add feature C"

MAIN_HEAD=$(git rev-parse HEAD)

# --- Disaster 1: Detached HEAD with unsaved work ---
echo "[1/5] Creating detached HEAD disaster..."
git checkout -q HEAD~3  # detach at initial commit
echo "important new work" > new-feature.txt
git add new-feature.txt && git commit -q -m "Important work in detached HEAD"
DETACHED_SHA=$(git rev-parse HEAD)
echo "${DETACHED_SHA}" > /tmp/lab-git-ops-detached-sha

# Go back to main
git checkout -q main

# --- Disaster 2: Force-push wiped commits ---
echo "[2/5] Simulating force-push damage..."
# Save the current HEAD, then reset back 3 commits
echo "${MAIN_HEAD}" > /tmp/lab-git-ops-original-head
git reset --hard HEAD~3 -q
# Now main only has the initial commit; features A, B, C are "lost"

# --- Disaster 3: Stuck merge conflict ---
echo "[3/5] Creating stuck merge conflict..."
# Create a branch from current position
git checkout -q -b feature-merge
echo "feature branch content" > conflict-file.txt
git add conflict-file.txt && git commit -q -m "Feature merge branch"

git checkout -q main
echo "main branch content" > conflict-file.txt
git add conflict-file.txt && git commit -q -m "Main branch conflicting change"

# Start merge — will conflict
git merge feature-merge --no-edit 2>/dev/null || true
# Leave the conflict unresolved

# --- Disaster 4: Deleted branch with dangling commit ---
echo "[4/5] Creating dangling commit..."
# Create a temp branch, commit, then delete the branch
git stash -q 2>/dev/null || true
git checkout -q -b secret-feature HEAD~1 2>/dev/null || git checkout -q -b secret-feature
echo "unreleased secret feature" > secret.txt
git add secret.txt && git commit -q -m "Unreleased feature - do not lose" --allow-empty 2>/dev/null || true
SECRET_SHA=$(git rev-parse HEAD)
echo "${SECRET_SHA}" > /tmp/lab-git-ops-secret-sha
git checkout -q main 2>/dev/null || git checkout -q --detach
git branch -D secret-feature -q 2>/dev/null || true

# --- Disaster 5: Corrupted index ---
echo "[5/5] Corrupting the index..."
echo "CORRUPT" > "${LAB_ROOT}/.git/index"

echo ""
echo "=== Setup Complete ==="
echo "Git disaster repo at: ${LAB_ROOT}"
echo ""
echo "Your mission:"
echo "  1. Recover from detached HEAD (commit ${DETACHED_SHA:0:8})"
echo "  2. Restore force-pushed commits (features A, B, C)"
echo "  3. Resolve the stuck merge conflict"
echo "  4. Recover the dangling secret-feature commit"
echo "  5. Fix the corrupted index"
echo ""
echo "Run ./grade.sh when done."
