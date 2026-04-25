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

# Block if plan was presented but not yet approved by the human.
# Claude creates this marker (via Bash) at the end of a plan-presentation turn,
# and removes it (via Bash) as the first action when the user approves.
if [ -f ".claude/.plan-approval-pending" ]; then
  echo "[plan-gate] BLOCK: plan presented but not yet approved — reply with 'yes' / 'go' to proceed." >&2
  exit 2
fi

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
# Exclude versioned files (*.v1.md, *.v2.md, etc.) — superseded plans do not satisfy the gate.
ACTIVE_PLAN=$(find "$PLANS" -maxdepth 1 -type f -name "*.md" ! -name "*.v[0-9]*.md" 2>/dev/null | head -1)

if [ ! -d "$PLANS" ] || [ -z "$ACTIVE_PLAN" ]; then
  echo "[plan-gate] BLOCK: no plan artifact in $PLANS. Run /plan first." >&2
  exit 2
fi

# Warn if the active plan is marked superseded (versioning race: plan renamed but new version not yet written).
if grep -qE "^\- \*\*Status:\*\* superseded" "$ACTIVE_PLAN" 2>/dev/null; then
  echo "[plan-gate] WARN: active plan has Status: superseded. Run /plan to create the next version." >&2
fi

# Require at least one active plan updated in the last 24h.
if ! find "$PLANS" -maxdepth 1 -type f -name "*.md" ! -name "*.v[0-9]*.md" -mtime -1 2>/dev/null | grep -q .; then
  echo "[plan-gate] WARN: no plan file modified in the last 24h. Confirm this task has an active plan." >&2
fi

exit 0
