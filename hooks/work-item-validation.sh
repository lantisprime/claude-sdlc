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

# ---- B3 file-level traceability (RFC-003 PR-5 warn / PR-8 block) ----
# Two enforcement paths sharing the same input plumbing:
#   - warn (PR-5, default): missing In-scope or plan-level REQ logs to stderr.
#   - block (PR-8, opt-in): if config/tools.json sets
#     enforcement.file_traceability="block" AND the plan has a structured
#     `## Traceability` table, every edited file must be a row in that table
#     with a REQ/TICKET/CR/ISSUE reference, else exit 2.
# Plans without the Traceability section fall back to warn-only regardless
# of config, so legacy plans never get blocked unexpectedly.

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

# Read enforcement.file_traceability (block | warn). Default warn — the example
# config ships warn as the post-RFC-003 baseline; users opt in to block.
ENFORCE_MODE="warn"
if command -v jq >/dev/null 2>&1 && [ -f "config/tools.json" ]; then
  CFG_MODE=$(jq -r '.enforcement.file_traceability // "warn"' config/tools.json 2>/dev/null || true)
  case "$CFG_MODE" in
    block|warn) ENFORCE_MODE="$CFG_MODE" ;;
  esac
fi

# Parse the structured `## Traceability` table. Format (PR-7 plan template):
#   | File | REQ/Ticket/CR | Change Type |
#   |---|---|---|
#   | path/to/file.ext | REQ-001 | modified |
# Emit "<path>\t<ref>" per data row. The header is detected by content
# (case-insensitive: file/path/source) so users can rename the column.
# The separator row is detected by shape (dashes/colons/spaces only).
TRACE_BLOCK=$(awk '
  /^## Traceability/ {f=1; next}
  /^## / {f=0}
  f && /^[[:space:]]*\|/ { print }
' "$PLAN" 2>/dev/null || true)

TRACE_ROWS=""
if [ -n "$TRACE_BLOCK" ]; then
  TRACE_ROWS=$(echo "$TRACE_BLOCK" | awk '
    BEGIN { FS="|" }
    {
      # Skip separator-shaped rows (only dashes/spaces/colons/pipes).
      if ($0 ~ /^[[:space:]]*\|[[:space:]:|-]+\|[[:space:]]*$/) next
      file=$2; ref=$3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", file)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", ref)
      if (file == "") next
      # Skip header rows by case-insensitive content match — accommodates
      # renames like `Path`, `Source File`, `file`, etc.
      lower=tolower(file)
      if (lower == "file" || lower == "path" || lower == "source" || lower == "source file") next
      printf "%s\t%s\n", file, ref
    }
  ' || true)
fi

TRACE_MATCH_PATH=""
TRACE_MATCH_REF=""
if [ -n "$TRACE_ROWS" ]; then
  while IFS=$'\t' read -r row_path row_ref; do
    if [ "$row_path" = "$TARGET_PATH" ]; then
      TRACE_MATCH_PATH="$row_path"
      TRACE_MATCH_REF="$row_ref"
      break
    fi
  done <<EOF_TRACE
$TRACE_ROWS
EOF_TRACE
fi

# Block path: opt-in via config AND plan has a Traceability section.
if [ "$ENFORCE_MODE" = "block" ] && [ -n "$TRACE_ROWS" ]; then
  if [ -z "$TRACE_MATCH_PATH" ]; then
    echo "[work-item] BLOCK: file '$FILE_PATH' is not listed in the active plan's '## Traceability' table. Add a row mapping the file to a REQ/TICKET/CR/ISSUE before editing." >&2
    exit 2
  fi
  if ! echo "$TRACE_MATCH_REF" | grep -qE '(REQ|TICKET|CR|ISSUE)-[0-9]+'; then
    echo "[work-item] BLOCK: file '$FILE_PATH' has no REQ/TICKET/CR/ISSUE reference in the '## Traceability' table (row reference: '${TRACE_MATCH_REF:-empty}')." >&2
    exit 2
  fi
  exit 0
fi

# Warn path (default + back-compat for plans without a Traceability section).
if [ -z "$IN_SCOPE" ]; then
  echo "[work-item] WARN: file '$FILE_PATH' is not listed in the active plan's '## In-scope files' section. Verify intentional, or update the plan." >&2
fi

if ! grep -qE '(REQ|TICKET|CR|ISSUE)-[0-9]+' "$PLAN"; then
  if [ "$ENFORCE_MODE" = "block" ]; then
    # User has opted in to block mode but the plan lacks the Traceability section,
    # so we fell through to warn. Make the inactive-block state explicit.
    echo "[work-item] WARN: plan $PLAN has no '## Traceability' section; enforcement.file_traceability=\"block\" is configured but inactive until the section is added (back-compat warn-only path)." >&2
  else
    echo "[work-item] WARN: no REQ/TICKET/CR/ISSUE reference (e.g. REQ-001, TICKET-42, CR-7, ISSUE-99) found in active plan $PLAN. Add a '## Traceability' table and set enforcement.file_traceability=\"block\" in config/tools.json to promote this to a hard block." >&2
  fi
fi

exit 0
