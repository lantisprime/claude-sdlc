#!/usr/bin/env bash
# work-item-validation.sh — PreToolUse hook for Edit/Write.
# Ensures the active plan references a valid work item (REQ / ticket / signed CR).
set -euo pipefail
[ -f ".claude/sdlc/.enabled" ] || exit 0

PLANS=".claude/sdlc/plans"
[ -d "$PLANS" ] || exit 0

# Find the most recently modified plan file.
PLAN=$(find "$PLANS" -type f -name "*.md" 2>/dev/null \
  | while IFS= read -r f; do
      printf '%s\t%s\n' \
        "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)" "$f"
    done \
  | sort -rn | head -1 | cut -f2- || true)
[ -z "${PLAN:-}" ] && exit 0

# Classification line must exist.
if ! grep -qiE '^\s*(Classification|Type)\s*:\s*(new-build|fix|change-request)' "$PLAN"; then
  echo "[work-item] BLOCK: plan $PLAN is missing a Classification (new-build|fix|change-request)." >&2
  exit 2
fi

# For CRs, require a sign-off file referenced in the plan.
if grep -qiE '^\s*(Classification|Type)\s*:\s*change-request' "$PLAN"; then
  CR_REF=$(grep -oE 'CR-[0-9]+' "$PLAN" | head -1 || true)
  if [ -z "$CR_REF" ] || [ ! -f ".claude/sdlc/sign-offs/${CR_REF}.md" ]; then
    echo "[work-item] BLOCK: CR in $PLAN has no signed artifact at .claude/sdlc/sign-offs/${CR_REF:-CR-?}.md" >&2
    exit 2
  fi
fi

# ---- B3 file-level traceability warning (RFC-003 PR-5) ----
# Warns (does not block) if the edited file is missing from the plan's
# In-scope files section or if the plan has no REQ/TICKET/CR reference.
# Block-level promotion is deferred to PR-8 once the plan template ships
# the per-file ## Traceability section (RFC-003 §C2 prerequisites).

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -n "$TOOL_INPUT" ] || exit 0

# Extract the edited file path: jq → grep/sed fallback → raw input as last resort.
FILE_PATH=""
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || true)
fi
if [ -z "$FILE_PATH" ]; then
  FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)
fi
[ -n "$FILE_PATH" ] || FILE_PATH="$TOOL_INPUT"

# Repair escape hatch: edits to .claude/sdlc/ artifacts always pass.
case "$FILE_PATH" in
  *.claude/sdlc/*) exit 0 ;;
esac

# Generated-file inheritance (RFC-003 §B3, schema reserved by PR-2).
# If config/tools.json's generated_files list contains an entry whose path matches
# the edited file, swap the path with the generator before running scope/REQ checks.
TARGET_PATH="$FILE_PATH"
if command -v jq >/dev/null 2>&1 && [ -f "config/tools.json" ]; then
  GEN_BY=$(jq -r --arg p "$FILE_PATH" \
    '.generated_files[]? | select(.path == $p) | .generated_by // empty' \
    config/tools.json 2>/dev/null || true)
  [ -n "$GEN_BY" ] && TARGET_PATH="$GEN_BY"
fi

# In-scope check: extract the `## In-scope files` block and exact-match TARGET_PATH
# against the first whitespace-separated token of each list entry. Token-level match
# avoids substring collisions like `foo.js` falsely matching `src/notfoo.js`.
IN_SCOPE_BLOCK=$(awk '/^## In-scope files/{f=1; next} /^## /{f=0} f' "$PLAN" 2>/dev/null || true)
IN_SCOPE=""
if [ -n "$IN_SCOPE_BLOCK" ]; then
  while IFS= read -r line; do
    cleaned=$(echo "$line" | sed -E 's/^[[:space:]]*[-*][[:space:]]*//;s/^[[:space:]]+//')
    token="${cleaned%% *}"
    if [ -n "$token" ] && [ "$token" = "$TARGET_PATH" ]; then
      IN_SCOPE=yes
      break
    fi
  done <<EOF_BLK
$IN_SCOPE_BLOCK
EOF_BLK
fi

if [ -z "$IN_SCOPE" ]; then
  echo "[work-item] WARN: file '$FILE_PATH' is not listed in the active plan's '## In-scope files' section. Verify intentional, or update the plan." >&2
fi

# REQ/ticket/CR existence check. Recognised prefixes are listed in the warning so
# users with non-canonical IDs (JIRA-style PROJ-123, GH-456, etc.) know to map them
# onto the four supported forms or rename in the plan.
if ! grep -qE '(REQ|TICKET|CR|ISSUE)-[0-9]+' "$PLAN"; then
  echo "[work-item] WARN: no REQ/TICKET/CR/ISSUE reference (e.g. REQ-001, TICKET-42, CR-7, ISSUE-99) found in active plan $PLAN. File-level traceability will be promoted to a hard block once RFC-003 PR-8 ships the ## Traceability section." >&2
fi

exit 0
