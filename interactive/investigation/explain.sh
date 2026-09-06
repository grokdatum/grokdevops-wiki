#!/usr/bin/env bash
# explain.sh — Record what you found during an investigation.
#
# Writes a journal entry to training/interactive/investigation/journal/<date>-<incident_id>.md
#
# Usage:
#   make explain
#   ./explain.sh
#
# Non-interactive by default: prints a template to fill in.
# Pass INTERACTIVE=1 to get prompted for each field.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

investigation_parse_no_args "$@"

mkdir -p "$JOURNAL_DIR"

# ── Pre-fill from state if available ────────────────────────────
if state_exists; then
  INCIDENT_ID=$(state_get incident_id)
  STARTED=$(state_get started_at)
  DESCRIPTION=$(state_get description)
else
  INCIDENT_ID="${INCIDENT_ID:-unknown}"
  STARTED="n/a"
  DESCRIPTION=""
fi

DATE=$(date -u '+%Y-%m-%d')
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
JOURNAL_FILE="$JOURNAL_DIR/${DATE}-${INCIDENT_ID}.md"

INTERACTIVE="${INTERACTIVE:-0}"

if [[ "$INTERACTIVE" == "1" ]]; then
  print_header "Explain: $INCIDENT_ID"

  read -rp "Symptom (what was broken?): " SYMPTOM
  read -rp "Evidence 1: " EV1
  read -rp "Evidence 2: " EV2
  read -rp "Evidence 3: " EV3
  read -rp "Root cause (1 line): " ROOT_CAUSE
  read -rp "Fix (commands used): " FIX
  read -rp "Verification (commands used): " VERIFY

  cat >> "$JOURNAL_FILE" <<EOF

---

## $INCIDENT_ID ($TIMESTAMP)

**Incident started:** $STARTED
**Description:** $DESCRIPTION

### Symptom
$SYMPTOM

### Key Evidence
1. $EV1
2. $EV2
3. $EV3

### Root Cause
$ROOT_CAUSE

### Fix
\`\`\`
$FIX
\`\`\`

### Verification
\`\`\`
$VERIFY
\`\`\`
EOF

  print_ok "Journal entry saved: $JOURNAL_FILE"

else
  # Non-interactive: generate template file
  if [[ -f "$JOURNAL_FILE" ]]; then
    print_warn "Journal file already exists: $JOURNAL_FILE"
    echo "Appending a new template section."
  fi

  cat >> "$JOURNAL_FILE" <<EOF

---

## $INCIDENT_ID ($TIMESTAMP)

**Incident started:** $STARTED
**Description:** $DESCRIPTION

### Symptom
<!-- What was broken? What did the user/alert see? -->

### Key Evidence
1. <!-- e.g. kubectl get pods showed CrashLoopBackOff -->
2. <!-- e.g. logs showed "connection refused on port 5432" -->
3. <!-- e.g. describe pod showed OOMKilled -->

### Root Cause
<!-- One line: what was misconfigured/broken and why -->

### Fix
\`\`\`
<!-- Commands you ran to fix it -->
\`\`\`

### Verification
\`\`\`
<!-- Commands you ran to confirm the fix -->
\`\`\`
EOF

  print_ok "Template written: $JOURNAL_FILE"
  echo "Edit the file, fill in the sections, then save."
  echo ""
  echo "  \${EDITOR:-vi} $JOURNAL_FILE"
fi
echo ""
