#!/usr/bin/env bash
# Validate curriculum outputs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
WARN=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "============================================"
echo "  CURRICULUM VALIDATION"
echo "============================================"
echo ""

# Check required directories
echo "--- Directory structure ---"
for dir in tracks levels coverage; do
  if [ -d "$SCRIPT_DIR/$dir" ]; then
    pass "Directory exists: $dir/"
  else
    fail "Missing directory: $dir/"
  fi
done
echo ""

# Check required files
echo "--- Required files ---"
for f in \
  README.md \
  tracks/foundations.md tracks/containers.md tracks/kubernetes_core.md \
  tracks/helm_and_release_ops.md tracks/observability.md tracks/incident_response.md \
  levels/level-1-foundations.md levels/level-2-container-platform.md \
  levels/level-3-production-kubernetes.md levels/level-4-operations-observability.md \
  levels/level-5-sre-incident-response.md \
  coverage/coverage.tsv coverage/gaps.md; do
  if [ -f "$SCRIPT_DIR/$f" ]; then
    pass "File exists: $f"
  else
    fail "Missing file: $f"
  fi
done
echo ""

# Validate TSV
echo "--- TSV validation ---"
for tsv in coverage/coverage.tsv; do
  f="$SCRIPT_DIR/$tsv"
  if [ -f "$f" ]; then
    cols=$(head -1 "$f" | awk -F'\t' '{print NF}')
    rows=$(wc -l < "$f")
    pass "$tsv: $cols columns, $rows rows"
  else
    fail "$tsv: not found"
  fi
done
echo ""

# Check metadata files exist for runtime labs
echo "--- Lab metadata ---"
for lab in "$REPO_ROOT"/training/interactive/runtime-labs/lab-runtime-*/; do
  name=$(basename "$lab")
  if [ -f "$lab/metadata.yaml" ]; then
    pass "Metadata: $name"
  else
    warn "No metadata: $name"
  fi
done
echo ""

# Check runbook metadata
echo "--- Runbook metadata ---"
for rb in "$REPO_ROOT"/training/library/runbooks/*.md; do
  name=$(basename "$rb" .md)
  if [ -f "$REPO_ROOT/training/library/runbooks/${name}.meta.yaml" ]; then
    pass "Metadata: $name"
  else
    warn "No metadata: $name"
  fi
done
echo ""

# Summary
echo "============================================"
echo "  SUMMARY: $PASS passed, $WARN warnings, $FAIL failed"
echo "============================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
