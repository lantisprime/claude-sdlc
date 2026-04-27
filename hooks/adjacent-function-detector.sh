#!/usr/bin/env bash
# adjacent-function-detector.sh — PostToolUse hook for Edit/Write.
# Uses `git diff` function-context hunk headers to detect modified functions.
# Flags functions not declared in the plan's "In-scope functions" list.
set -euo pipefail
if [ -f ".claude/sdlc/.suspended" ]; then
  echo "[SDLC] Workflow suspended — adjacent-function check is paused." >&2
  exit 0
fi
[ -f ".claude/sdlc/.enabled" ] || exit 0

command -v git >/dev/null 2>&1 || exit 0
[ -d .git ] || exit 0

PLANS=".claude/sdlc/plans"
PLAN=$(find "$PLANS" -type f -name "*.md" 2>/dev/null \
  | while IFS= read -r f; do
      printf '%s\t%s\n' \
        "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)" "$f"
    done \
  | sort -rn | head -1 | cut -f2- || true)
[ -z "${PLAN:-}" ] && exit 0

IN_SCOPE_FNS=$(awk '/^##?[[:space:]]*In-scope functions/{flag=1; next} /^##?[[:space:]]/{flag=0} flag && /^[-*]/{gsub(/^[-*] +/,""); print}' "$PLAN" | tr -d '`')

# Parse @@ ... @@ hunk headers — the trailing context usually names the function.
MODIFIED_FNS=$(git diff -U0 --function-context 2>/dev/null \
  | grep -E '^@@ .* @@ ' \
  | sed -E 's/^@@ .* @@ //' \
  | awk '{print $0}' \
  | sort -u || true)

[ -z "$MODIFIED_FNS" ] && exit 0

UNEXPECTED=""
while IFS= read -r fn; do
  [ -z "$fn" ] && continue
  if ! echo "$IN_SCOPE_FNS" | grep -qF "$fn"; then
    UNEXPECTED="$UNEXPECTED
  - $fn"
  fi
done <<< "$MODIFIED_FNS"

if [ -n "$UNEXPECTED" ]; then
  echo "[adjacent-fn] WARN: functions modified but not in plan's In-scope functions list:$UNEXPECTED" >&2
  echo "[adjacent-fn] If this was intentional, follow the scope-extension protocol (skills/surgical-edit/SKILL.md)." >&2
fi

exit 0
