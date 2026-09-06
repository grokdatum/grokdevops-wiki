#!/usr/bin/env bash
# hints.sh — Progressive hint system for active incidents.
#
# Usage:
#   make hint           # Show hint level 1 (default)
#   make hint HINT=2    # Show hint level 2
#   HINT=3 ./hints.sh   # Show hint level 3
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

investigation_parse_no_args "$@"

require_active_incident || exit 1

INCIDENT_ID=$(get_active_incident)
HINT_LEVEL="${HINT:-1}"

# Validate hint level
if ! [[ "$HINT_LEVEL" =~ ^[1-4]$ ]]; then
  print_err "HINT must be 1-4. Got: $HINT_LEVEL"
  exit 1
fi

# Resolve hint file: incident-specific or generic fallback
HINT_FILE="$HINTS_DIR/${INCIDENT_ID}.md"
if [[ ! -f "$HINT_FILE" ]]; then
  HINT_FILE="$HINTS_DIR/generic.md"
fi

if [[ ! -f "$HINT_FILE" ]]; then
  print_err "No hint file found for $INCIDENT_ID (and no generic fallback)."
  exit 1
fi

print_header "Hint $HINT_LEVEL / 4 for: $INCIDENT_ID"

# Extract the requested hint level from the file.
# Format: lines between "## Hint N" and the next "## Hint" or EOF.
in_hint=false
found=false
while IFS= read -r line; do
  if [[ "$line" =~ ^##[[:space:]]+Hint[[:space:]]+${HINT_LEVEL} ]]; then
    in_hint=true
    found=true
    continue
  fi
  if [[ "$in_hint" == true ]] && [[ "$line" =~ ^##[[:space:]]+Hint ]]; then
    break
  fi
  if [[ "$in_hint" == true ]]; then
    echo "$line"
  fi
done < "$HINT_FILE"

if [[ "$found" == false ]]; then
  print_warn "No hint level $HINT_LEVEL available for $INCIDENT_ID."
fi

echo ""
if [[ "$HINT_LEVEL" -lt 4 ]]; then
  next=$((HINT_LEVEL + 1))
  printf "${DIM}Need more help? make hint HINT=%d${RST}\n" "$next"
fi
echo ""
