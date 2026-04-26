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

exit 0
