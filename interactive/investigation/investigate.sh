#!/usr/bin/env bash
# investigate.sh — Print a step-by-step investigation plan for the active incident.
#
# Usage:
#   make investigate
#   ./investigate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

investigation_parse_no_args "$@"

require_active_incident || exit 1

INCIDENT_ID=$(get_active_incident)
STARTED=$(state_get started_at)
RUNBOOK_FILE=$(resolve_playbook "$INCIDENT_ID")

print_header "Investigation Plan: $INCIDENT_ID"
printf "Started: %s\n" "$STARTED"
printf "Runbook: %s\n\n" "$(basename "$RUNBOOK_FILE" .md)"

# ── Map references ──────────────────────────────────────────────
MAP_ROW=$(map_lookup "$INCIDENT_ID")
if [[ -n "$MAP_ROW" ]]; then
  RUNBOOK=$(echo "$MAP_ROW" | cut -f3)
  LAB=$(echo "$MAP_ROW" | cut -f4)
  QUEST=$(echo "$MAP_ROW" | cut -f5)
  if [[ -n "$RUNBOOK" ]]; then
    printf "${DIM}Runbook:  %s${RST}\n" "$RUNBOOK"
  fi
  if [[ -n "$LAB" ]]; then
    printf "${DIM}Lab:      %s${RST}\n" "$LAB"
  fi
  if [[ -n "$QUEST" ]]; then
    printf "${DIM}Quest:    %s${RST}\n" "$QUEST"
  fi
  echo ""
fi

# ── Parse and print runbook triage steps ──────────────────────
# Runbooks use "## Fast Triage" with fenced ```bash blocks.
# Also supports legacy "## Investigation Steps" with numbered steps.
in_section=false
step_num=0
in_fence=false
while IFS= read -r line; do
  # Detect triage/investigation section headers
  if [[ "$line" =~ ^##[[:space:]]+(Fast[[:space:]]+)?Triage ]] || \
     [[ "$line" =~ ^##[[:space:]]+Investigation[[:space:]]+Steps ]]; then
    in_section=true
    continue
  fi
  if [[ "$in_section" == true ]] && [[ "$line" =~ ^##[[:space:]]+ ]]; then
    break
  fi
  if [[ "$in_section" == false ]]; then
    continue
  fi

  # Handle fenced code blocks (```bash ... ```)
  if [[ "$line" =~ ^\`\`\` ]]; then
    in_fence=$( [[ "$in_fence" == false ]] && echo true || echo false )
    continue
  fi
  if [[ "$in_fence" == true ]]; then
    # Strip leading comment marker for display
    local_line="${line#\# }"
    if [[ "$local_line" != "$line" ]]; then
      # Was a comment line — show as a step description
      step_num=$((step_num + 1))
      print_step "$step_num" "$local_line"
    elif [[ -n "$line" ]]; then
      print_cmd "$line"
    fi
    continue
  fi

  # Numbered step line (legacy playbook format)
  if [[ "$line" =~ ^[0-9]+\.[[:space:]]+(.*) ]]; then
    step_num=$((step_num + 1))
    print_step "$step_num" "${BASH_REMATCH[1]}"
  # Inline backtick command
  elif [[ "$line" =~ ^[[:space:]]+\`([^\`]+)\` ]] || [[ "$line" =~ ^[[:space:]]+\$[[:space:]]+(.*) ]]; then
    cmd="${BASH_REMATCH[1]}"
    print_cmd "$cmd"
  elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(Bad:|Look) ]]; then
    text="${line#*- }"
    print_expect "$text"
  elif [[ -n "$line" ]] && [[ "$line" != "---" ]]; then
    printf "  %s\n" "$line"
  fi
done < "$RUNBOOK_FILE"

if [[ "$step_num" -eq 0 ]]; then
  print_warn "No structured triage steps found. Showing raw content:"
  echo ""
  sed -n '/^## Symptoms/,/^## [A-Z]/p' "$RUNBOOK_FILE" | head -40
fi

echo ""
printf "${BOLD}What next:${RST}\n"
echo "  make hint           # Get a hint (level 1)"
echo "  make hint HINT=2    # Deeper hint"
echo "  make explain        # Record your findings"
echo ""
