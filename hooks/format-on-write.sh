#!/usr/bin/env bash
# format-on-write.sh — PostToolUse hook. Runs the configured formatter.
set -euo pipefail
[ -f ".claude/sdlc/.enabled" ] || exit 0

CONFIG="config/tools.json"
[ -f "$CONFIG" ] || exit 0

# Extract formatter.command without jq dependency.
FORMATTER=$(grep -A2 '"formatter"' "$CONFIG" | grep '"command"' | head -1 \
  | sed -E 's/.*"command"\s*:\s*"([^"]*)".*/\1/')

if [ -z "$FORMATTER" ] || [ "$FORMATTER" = "null" ]; then exit 0; fi

command -v git >/dev/null 2>&1 || exit 0
CHANGED=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)
CHANGED=$(echo "$CHANGED" | sort -u | grep -v '^\.claude/sdlc/' || true)
[ -z "$CHANGED" ] && exit 0

# shellcheck disable=SC2086
echo "$CHANGED" | xargs -r $FORMATTER || {
  echo "[format] formatter reported errors; see output above." >&2
}

exit 0
