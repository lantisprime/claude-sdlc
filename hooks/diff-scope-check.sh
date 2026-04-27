#!/usr/bin/env bash
# diff-scope-check.sh — PostToolUse hook for Edit/Write.
# Compares git diff against the plan's In-scope files list.
set -euo pipefail
if [ -f ".claude/sdlc/.suspended" ]; then
  echo "[SDLC] Workflow suspended — diff-scope check is paused." >&2
  exit 0
fi
[ -f ".claude/sdlc/.enabled" ] || exit 0

command -v git >/dev/null 2>&1 || exit 0
[ -d .git ] || exit 0

PLANS=".claude/sdlc/plans"
# Exclude versioned files (*.v1.md, *.v2.md, etc.) — scope check runs against the active plan only.
PLAN=$(find "$PLANS" -maxdepth 1 -type f -name "*.md" ! -name "*.v[0-9]*.md" 2>/dev/null \
  | while IFS= read -r f; do
      printf '%s\t%s\n' \
        "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)" "$f"
    done \
  | sort -rn | head -1 | cut -f2- || true)
[ -z "${PLAN:-}" ] && exit 0

# Extract in-scope files — lines under the "In-scope files" header, bullet-listed.
IN_SCOPE=$(awk '/^##?[[:space:]]*In-scope files/{flag=1; next} /^##?[[:space:]]/{flag=0} flag && /^[-*]/{gsub(/^[-*] +/,""); print}' "$PLAN" | tr -d '`' | awk '{print $1}')

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
