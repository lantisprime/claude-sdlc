#!/usr/bin/env bash
# bash-safety.sh — PreToolUse hook for Bash. Blocks obvious footguns without explicit confirmation.
set -euo pipefail

CMD="${CLAUDE_TOOL_INPUT:-}"
[ -z "$CMD" ] && exit 0

case "$CMD" in
  *"rm -rf /"*|*"rm -rf ~"*|*"rm -rf ."*|*":(){:|:&};:"*)
    echo "[bash-safety] BLOCK: destructive command pattern detected." >&2
    exit 2 ;;
  *"curl "*"| sh"*|*"curl "*"|sh"*|*"wget "*"| sh"*|*"wget "*"|sh"*)
    echo "[bash-safety] BLOCK: pipe-to-shell pattern. Download, review, then run." >&2
    exit 2 ;;
  *"git push"*"--force"*|*"git push"*"-f"*)
    echo "[bash-safety] WARN: force push — confirm the target branch is not protected." >&2 ;;
esac

exit 0
