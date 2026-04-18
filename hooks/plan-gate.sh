#!/usr/bin/env bash
# plan-gate.sh — PreToolUse hook for Edit/Write. Blocks edits with no plan artifact.
set -euo pipefail

PLANS=".claude/sdlc/plans"

# Allow edits to SDLC artifacts themselves (plans, gates, templates, etc.)
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
if echo "$TOOL_INPUT" | grep -qE '\.claude/sdlc/'; then exit 0; fi

if [ ! -d "$PLANS" ] || [ -z "$(ls -A "$PLANS" 2>/dev/null)" ]; then
  echo "[plan-gate] BLOCK: no plan artifact in $PLANS. Run /plan first." >&2
  exit 2
fi

# Require at least one plan updated in the last 24h (active task).
if ! find "$PLANS" -type f -name "*.md" -mtime -1 | grep -q .; then
  echo "[plan-gate] WARN: no plan file modified in the last 24h. Confirm this task has an active plan." >&2
fi

exit 0
