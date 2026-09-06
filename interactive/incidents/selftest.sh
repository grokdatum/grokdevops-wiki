#!/usr/bin/env bash
# Smoke test for the incident simulator (no cluster required)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

incident_parse_no_args "$@"

PASS=0
FAIL=0

assert_ok() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] $label"
    PASS=$(( PASS + 1 ))
  else
    echo "[FAIL] $label"
    FAIL=$(( FAIL + 1 ))
  fi
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "[PASS] $label"
    PASS=$(( PASS + 1 ))
  else
    echo "[FAIL] $label (expected='$expected' got='$actual')"
    FAIL=$(( FAIL + 1 ))
  fi
}

echo "============================================"
echo "  INCIDENT SIMULATOR SELF-TEST"
echo "============================================"
echo ""

# Test 1: Scenario listing
echo "--- Scenario listing ---"
scenarios=$(list_scenarios)
count=$(echo "$scenarios" | wc -l)
assert_ok "list_scenarios returns results" test "$count" -ge 15
echo "  Found $count scenarios"
echo ""

# Test 2: Each scenario has required functions
echo "--- Scenario contract ---"
for scenario in $scenarios; do
  f="${SCENARIOS_DIR}/${scenario}.sh"
  assert_ok "$scenario: file exists" test -f "$f"
  # Check that required functions are defined
  (
    source "$f"
    assert_ok "$scenario: incident_brief" type incident_brief
    assert_ok "$scenario: inject" type inject
    assert_ok "$scenario: restore" type restore
    assert_ok "$scenario: verify" type verify
  )
done
echo ""

# Test 3: State management
echo "--- State management ---"
TEST_STATE_FILE=$(mktemp)
STATE_FILE="$TEST_STATE_FILE"

assert_ok "no state initially" test ! -s "$STATE_FILE"

state_write "test-incident" "grokdevops" "true"
assert_ok "state file created" test -f "$STATE_FILE"
assert_eq "incident_id" "test-incident" "$(state_get incident_id)"
assert_eq "namespace" "grokdevops" "$(state_get namespace)"
assert_eq "dry_run" "True" "$(state_get dry_run)"

state_clear
assert_ok "state cleared" test ! -f "$STATE_FILE"
rm -f "$TEST_STATE_FILE"
echo ""

# Test 4: Scenario selection
echo "--- Scenario selection ---"
SEED=42
selected=$(select_scenario)
assert_ok "select with seed returns result" test -n "$selected"
selected2=$(select_scenario)
assert_eq "seed is deterministic" "$selected" "$selected2"

INCIDENT_ID="crashloop-bad-command"
selected3=$(select_scenario)
assert_eq "explicit selection" "crashloop-bad-command" "$selected3"
INCIDENT_ID=""
SEED=""
echo ""

# Test 5: Namespace validation
echo "--- Namespace validation ---"
assert_ok "approved namespace: grokdevops" check_namespace_approved "grokdevops"
assert_ok "approved namespace: monitoring" check_namespace_approved "monitoring"
if (check_namespace_approved "production" 2>/dev/null); then
  echo "[FAIL] should reject unapproved namespace"
  FAIL=$(( FAIL + 1 ))
else
  echo "[PASS] rejects unapproved namespace"
  PASS=$(( PASS + 1 ))
fi
echo ""

# Test 6: Dry-run incident (no cluster)
echo "--- Dry-run incident ---"
DRY_RUN=true
INCIDENT_ID="crashloop-bad-command"
SCENARIO_FILE="${SCENARIOS_DIR}/${INCIDENT_ID}.sh"
source "$SCENARIO_FILE"
assert_ok "incident_brief runs" incident_brief
INCIDENT_ID=""
echo ""

# Summary
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "============================================"

[[ $FAIL -eq 0 ]]
