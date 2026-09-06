#!/usr/bin/env bash
# selftest.sh — Verify investigation engine scripts run without errors.
# Non-destructive: creates a mock incident state, tests scripts, cleans up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

investigation_parse_no_args "$@"

PASSED=0
FAILED=0
CLEANUP_STATE=false

pass() { PASSED=$((PASSED + 1)); printf "  ${GREEN}PASS${RST} %s\n" "$1"; }
fail() { FAILED=$((FAILED + 1)); printf "  ${RED}FAIL${RST} %s\n" "$1"; }

print_header "Investigation Engine Self-Test"

# ── Test 1: lib/common.sh sources without error ─────────────────
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
  pass "lib/common.sh exists and sourced"
else
  fail "lib/common.sh not found"
fi

# ── Test 2: All scripts are executable (or at least parseable) ──
for script in investigate.sh hints.sh explain.sh trigger.sh; do
  if bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
    pass "$script syntax OK"
  else
    fail "$script syntax error"
  fi
done

# ── Test 3: map.tsv exists and has content ──────────────────────
if [[ -f "$MAP_FILE" ]] && [[ $(wc -l < "$MAP_FILE") -gt 1 ]]; then
  pass "map.tsv exists ($(wc -l < "$MAP_FILE") lines)"
else
  fail "map.tsv missing or empty"
fi

# ── Test 4: All runbooks referenced in map.tsv resolve ──────────
map_ok=true
while IFS=$'\t' read -r iid pid runbook lab quest; do
  [[ "$iid" == "incident_id" ]] && continue
  resolved=$(resolve_playbook "$pid")
  if [[ ! -f "$resolved" ]]; then
    fail "runbook missing for $iid (resolved: $resolved)"
    map_ok=false
  fi
done < "$MAP_FILE"
if [[ "$map_ok" == true ]]; then
  pass "all mapped runbooks resolve"
fi

# ── Test 5: Hint files exist for mapped incidents ───────────────
hints_ok=true
while IFS=$'\t' read -r iid pid _ _ _; do
  [[ "$iid" == "incident_id" ]] && continue
  hf="$HINTS_DIR/${iid}.md"
  if [[ ! -f "$hf" ]]; then
    fail "hint file missing: $hf"
    hints_ok=false
  fi
done < "$MAP_FILE"
if [[ "$hints_ok" == true ]]; then
  pass "all mapped hint files exist"
fi

# ── Test 6: Generic hint fallback exists ────────────────────────
if [[ -f "$HINTS_DIR/generic.md" ]]; then
  pass "generic hint fallback exists"
else
  fail "generic.md hint fallback missing"
fi

# ── Test 7: Create mock state and test investigate.sh ───────────
if ! state_exists; then
  CLEANUP_STATE=true
  state_create "probe-failure" "selftest" "Self-test mock incident"
  pass "mock incident state created"
else
  pass "existing incident state found (using it)"
fi

# ── Test 8: investigate.sh runs without error ───────────────────
if bash "$SCRIPT_DIR/investigate.sh" > /dev/null 2>&1; then
  pass "investigate.sh runs OK"
else
  fail "investigate.sh returned error"
fi

# ── Test 9: hints.sh runs without error (level 1) ──────────────
if HINT=1 bash "$SCRIPT_DIR/hints.sh" > /dev/null 2>&1; then
  pass "hints.sh (HINT=1) runs OK"
else
  fail "hints.sh returned error"
fi

# ── Test 10: explain.sh runs in non-interactive mode ────────────
EXPLAIN_OUT=$(bash "$SCRIPT_DIR/explain.sh" 2>&1) || true
if echo "$EXPLAIN_OUT" | grep -q "Template written\|Journal file already exists"; then
  pass "explain.sh produces journal template"
  # Clean up test journal entry
  rm -f "$JOURNAL_DIR"/????-??-??-probe-failure.md 2>/dev/null || true
else
  fail "explain.sh did not produce expected output"
fi

# ── Test 11: trigger.sh --list works ────────────────────────────
if bash "$SCRIPT_DIR/trigger.sh" --list > /dev/null 2>&1; then
  pass "trigger.sh --list runs OK"
else
  fail "trigger.sh --list returned error"
fi

# ── Cleanup ─────────────────────────────────────────────────────
if [[ "$CLEANUP_STATE" == true ]]; then
  state_remove
fi

# ── Summary ─────────────────────────────────────────────────────
echo ""
TOTAL=$((PASSED + FAILED))
if [[ "$FAILED" -eq 0 ]]; then
  printf "${GREEN}All %d tests passed.${RST}\n" "$TOTAL"
else
  printf "${RED}%d/%d tests failed.${RST}\n" "$FAILED" "$TOTAL"
  exit 1
fi
