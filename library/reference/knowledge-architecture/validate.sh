#!/usr/bin/env bash
# Validate knowledge architecture outputs
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
echo "  KNOWLEDGE ARCHITECTURE VALIDATION"
echo "============================================"
echo ""

# Check required directories
echo "--- Directory structure ---"
for dir in concepts failures commands; do
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
  INVENTORY.md NAV.md crosslinks.tsv \
  concepts/concept_graph.json concepts/concept_index.md \
  concepts/concept_dependency.tsv concepts/concept_assets.tsv concepts/concept_aliases.tsv \
  failures/failure_taxonomy.md failures/failure_patterns.tsv \
  failures/failure_to_concept.tsv failures/failure_assets.tsv \
  commands/command_intelligence.tsv commands/top_commands.md \
  commands/kubectl_debugging_flow.md commands/helm_debugging_flow.md \
  commands/observability_debugging_flow.md; do
  if [ -f "$SCRIPT_DIR/$f" ]; then
    pass "File exists: $f"
  else
    fail "Missing file: $f"
  fi
done
echo ""

# Validate TSV column counts
echo "--- TSV column validation ---"
validate_tsv() {
  local file="$1"
  local expected_cols="$2"
  local label="$3"
  if [ ! -f "$file" ]; then
    fail "$label: file not found"
    return
  fi
  local header_cols
  header_cols=$(head -1 "$file" | awk -F'\t' '{print NF}')
  if [ "$header_cols" -eq "$expected_cols" ]; then
    pass "$label: $header_cols columns (expected $expected_cols)"
  else
    fail "$label: $header_cols columns (expected $expected_cols)"
  fi
  # Check all rows have same column count as header
  local bad_rows
  bad_rows=$(awk -F'\t' -v cols="$header_cols" 'NR>1 && NF!=cols {count++} END {print count+0}' "$file")
  if [ "$bad_rows" -eq 0 ]; then
    pass "$label: all rows consistent"
  else
    warn "$label: $bad_rows rows with inconsistent column count"
  fi
}

validate_tsv "$SCRIPT_DIR/concepts/concept_dependency.tsv" 2 "concept_dependency.tsv"
validate_tsv "$SCRIPT_DIR/concepts/concept_assets.tsv" 3 "concept_assets.tsv"
validate_tsv "$SCRIPT_DIR/concepts/concept_aliases.tsv" 2 "concept_aliases.tsv"
validate_tsv "$SCRIPT_DIR/failures/failure_patterns.tsv" 4 "failure_patterns.tsv"
validate_tsv "$SCRIPT_DIR/failures/failure_to_concept.tsv" 2 "failure_to_concept.tsv"
validate_tsv "$SCRIPT_DIR/failures/failure_assets.tsv" 3 "failure_assets.tsv"
validate_tsv "$SCRIPT_DIR/crosslinks.tsv" 5 "crosslinks.tsv"
echo ""

# Best-effort path check for referenced paths
echo "--- Path reference check (best-effort) ---"
checked=0
missing=0
while IFS=$'\t' read -r _ _ path_or_ref; do
  # Skip header
  [ "$path_or_ref" = "path_or_ref" ] && continue
  # Skip glob patterns
  [[ "$path_or_ref" == *"*"* ]] && continue
  checked=$((checked+1))
  if [ ! -e "$REPO_ROOT/$path_or_ref" ]; then
    warn "Referenced path not found: $path_or_ref"
    missing=$((missing+1))
  fi
done < "$SCRIPT_DIR/concepts/concept_assets.tsv"
if [ "$missing" -eq 0 ]; then
  pass "All $checked referenced paths exist"
else
  warn "$missing of $checked referenced paths not found"
fi
echo ""

# JSON validation
echo "--- JSON validation ---"
if command -v python3 &>/dev/null; then
  if python3 -c "import json; json.load(open('$SCRIPT_DIR/concepts/concept_graph.json'))" 2>/dev/null; then
    concept_count=$(python3 -c "import json; d=json.load(open('$SCRIPT_DIR/concepts/concept_graph.json')); print(len(d.get('concepts',[])))")
    pass "concept_graph.json: valid JSON, $concept_count concepts"
  else
    fail "concept_graph.json: invalid JSON"
  fi
else
  warn "python3 not available, skipping JSON validation"
fi
echo ""

# Summary
echo "============================================"
echo "  SUMMARY: $PASS passed, $WARN warnings, $FAIL failed"
echo "============================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
