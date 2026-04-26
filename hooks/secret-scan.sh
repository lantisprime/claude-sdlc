#!/usr/bin/env bash
# secret-scan.sh — PostToolUse hook. Runs the configured secret scanner and blocks on findings.
set -euo pipefail
# No .enabled guard — credential scanning runs regardless of activation state (RFC §4.2).

CONFIG="config/tools.json"
[ -f "$CONFIG" ] || exit 0

_cmd_line=$(grep -A2 '"secret_scanner"' "$CONFIG" | grep '"command"' | head -1 || true)
if echo "$_cmd_line" | grep -qE '"command"[[:space:]]*:[[:space:]]*"'; then
  SCANNER=$(echo "$_cmd_line" | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
else
  SCANNER=""
fi

if [ -z "$SCANNER" ]; then exit 0; fi

# shellcheck disable=SC2086
if ! $SCANNER; then
  echo "[secret-scan] BLOCK: secret scanner reported findings. Resolve before continuing." >&2
  exit 2
fi

exit 0
