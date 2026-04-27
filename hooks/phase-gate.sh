#!/usr/bin/env bash
# phase-gate.sh — phase progression enforcement.
#   Stop event: advisory reminder to sign off after a phase.
#   PreToolUse Edit/Write/MultiEdit: blocks edits when the prior phase gate is missing.
# Branch detection: $CLAUDE_HOOK_EVENT primary; falls back to $CLAUDE_TOOL_INPUT presence.
set -euo pipefail

if [ -f ".claude/sdlc/.suspended" ]; then
  echo "[SDLC] Workflow suspended — phase-gate check is paused." >&2
  exit 0
fi
[ -f ".claude/sdlc/.enabled" ] || exit 0

GATES=".claude/sdlc/gates"
PLANS=".claude/sdlc/plans"
EVENT="${CLAUDE_HOOK_EVENT:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Resolve event: explicit env var wins; otherwise infer from tool-input presence.
if [ -z "$EVENT" ]; then
  if [ -n "$TOOL_INPUT" ]; then
    EVENT="PreToolUse"
  else
    EVENT="Stop"
  fi
fi

case "$EVENT" in
  Stop)
    # ---- Stop path: 2-hour reminder ----
    [ -d "$GATES" ] || exit 0
    RECENT=$(find "$GATES" -type f -name "*.md" -mmin -120 2>/dev/null | head -1 || true)
    if [ -z "$RECENT" ]; then
      echo "[phase-gate] INFO: no gate file updated in the last 2 hours. If you just completed a phase, sign off with the relevant template before starting the next." >&2
    fi
    exit 0
    ;;
  PreToolUse)
    : # fall through to PreToolUse logic below
    ;;
  *)
    # Unknown event — exit silently rather than misroute.
    exit 0
    ;;
esac

# ---- PreToolUse path: prior-gate enforcement ----

# Repair escape hatch: edits to .claude/sdlc/ artifacts always pass.
if echo "$TOOL_INPUT" | grep -qE '\.claude/sdlc/'; then exit 0; fi

# Find the active plan; defer to plan-gate.sh if absent.
[ -d "$PLANS" ] || exit 0
ACTIVE_PLAN=$(find "$PLANS" -maxdepth 1 -type f -name "*.md" ! -name "*.v[0-9]*.md" 2>/dev/null | head -1 || true)
[ -n "$ACTIVE_PLAN" ] || exit 0

# Parse "Phase:" or "Active Phase:" — accepts plain, list-bulleted, and **bold** forms.
PHASE=$(grep -iE '^[[:space:]]*[-*]?[[:space:]]*(\*\*)?(Active[[:space:]]+)?[Pp]hase:' "$ACTIVE_PLAN" 2>/dev/null \
  | head -1 \
  | sed -E 's/.*[Pp]hase:[*[:space:]]*//' \
  | awk '{print tolower($1)}' || true)

case "$PHASE" in
  plan|docs)
    # First phase or cross-cutting — no prior gate required.
    exit 0
    ;;
  analyze|design|build|test|deploy|support)
    : # continue
    ;;
  *)
    echo "[phase-gate] WARN: active plan has no recognized Phase field (got: '${PHASE:-<empty>}'). Cannot enforce prior-gate check." >&2
    exit 0
    ;;
esac

SLUG=$(basename "$ACTIVE_PLAN" .md)

case "$PHASE" in
  analyze) PRIOR_PREFIXES="plan" ;;
  design)  PRIOR_PREFIXES="analyze" ;;
  build)   PRIOR_PREFIXES="design" ;;
  test)    PRIOR_PREFIXES="build" ;;
  deploy)  PRIOR_PREFIXES="test" ;;
  support) PRIOR_PREFIXES="deploy support-transition" ;;
esac

GATE_EXISTS=""
for prefix in $PRIOR_PREFIXES; do
  if [ -f "$GATES/${prefix}-${SLUG}.md" ]; then
    GATE_EXISTS="yes"
    break
  fi
done

[ -n "$GATE_EXISTS" ] && exit 0

# Gate absent — determine severity by file extension.
# Try JSON parse first; fall back to treating raw input as a path (used by tests and simple invocations).
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
  | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)
[ -n "$FILE_PATH" ] || FILE_PATH="$TOOL_INPUT"
EXT="${FILE_PATH##*.}"
EXPECTED="${GATES}/${PRIOR_PREFIXES%% *}-${SLUG}.md"

case "$EXT" in
  md|rst|txt)
    echo "[phase-gate] WARN: active phase is '${PHASE}' but no prior gate found for task '${SLUG}' (expected ${EXPECTED}). Documentation file edit allowed; sign off when ready." >&2
    exit 0
    ;;
esac

echo "[phase-gate] BLOCK: active phase is '${PHASE}' but no prior gate found for task '${SLUG}' (expected ${EXPECTED}). Sign off the prior phase before continuing." >&2
exit 2
