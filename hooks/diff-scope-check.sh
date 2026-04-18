#!/usr/bin/env bash
# diff-scope-check.sh — PostToolUse hook for Edit/Write.
# Compares git diff against the plan's In-scope files list.
set -euo pipefail

command -v git >/dev/null 2>&1 || exit 0
[ -d .git ] || exit 0

PLANS=".claude/sdlc/plans"
PLAN=$(find "$PLANS" -type f -name "*.md" -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- || true)
[ -z "${PLAN:-}" ] && exit 0

# Extract in-scope files — lines under the "In-scope files" header, bullet-listed.
IN_SCOPE=$(awk '/^##?\s*In-scope files/{flag=1; next} /^##? /{flag=0} flag && /^[-*]/{gsub(/^[-*] +/,""); print}' "$PLAN" | tr -d '`' | awk '{print $1}')

CHANGED=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)
CHANGED=$(echo "$CHANGED" | sort -u | grep -v '^\.claude/sdlc/' || true)

[ -z "$CHANGED" ] && exit 0

OUT_OF_SCOPE=""
for f in $CHANGED; do
  if ! echo "$IN_SCOPE" | grep -qxF "$f"; then
    OUT_OF_SCOPE="$OUT_OF_SCOPE $f"
  fi
done

if [ -n "$OUT_OF_SCOPE" ]; then
  echo "[diff-scope] WARN: files modified but not in plan's In-scope list:$OUT_OF_SCOPE" >&2
  echo "[diff-scope] Either extend scope via the protocol in skills/surgical-edit/SKILL.md, or revert these." >&2
  # Non-blocking warning — surgical-edit skill and the human gate are the final arbiters.
fi

exit 0
