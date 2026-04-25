#!/usr/bin/env bash
# plan-gate.sh — PreToolUse hook for Edit/Write. Blocks edits with no plan artifact.
# Also warns when scope.md is absent or the scope gate has not been signed.
set -euo pipefail

PLANS=".claude/sdlc/plans"
GATES=".claude/sdlc/gates"
SCOPE=".claude/sdlc/scope.md"

# Allow edits to SDLC artifacts themselves (plans, gates, templates, scope-drafts, etc.)
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
if echo "$TOOL_INPUT" | grep -qE '\.claude/sdlc/'; then exit 0; fi

# --- Scope gate check (warn-level) ---
# Warn if scope.md is absent — the plan skill will handle creation, but surface early.
if [ ! -f "$SCOPE" ]; then
  echo "[plan-gate] WARN: .claude/sdlc/scope.md not found. Run /plan to create a scope before building." >&2
fi

# Warn if scope gate file is absent (gates/scope-<project>.md pattern).
if [ -d "$GATES" ]; then
  if ! find "$GATES" -maxdepth 1 -name "scope-*.md" | grep -q .; then
    echo "[plan-gate] WARN: no scope gate found in $GATES. Scope has not been signed. Run /plan to complete scope sign-off." >&2
  fi
fi

# --- Plan artifact check (block-level) ---
if [ ! -d "$PLANS" ] || [ -z "$(ls -A "$PLANS" 2>/dev/null)" ]; then
  echo "[plan-gate] BLOCK: no plan artifact in $PLANS. Run /plan first." >&2
  exit 2
fi

# Require at least one plan updated in the last 24h (active task).
if ! find "$PLANS" -type f -name "*.md" -mtime -1 | grep -q .; then
  echo "[plan-gate] WARN: no plan file modified in the last 24h. Confirm this task has an active plan." >&2
fi

exit 0
