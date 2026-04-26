#!/usr/bin/env bash
# phase-gate.sh — Stop hook. Reminds the user that ending a phase requires a gate file.
set -euo pipefail
[ -f ".claude/sdlc/.enabled" ] || exit 0

GATES=".claude/sdlc/gates"
[ -d "$GATES" ] || exit 0

RECENT=$(find "$GATES" -type f -name "*.md" -mmin -120 2>/dev/null | head -1 || true)
if [ -z "$RECENT" ]; then
  echo "[phase-gate] INFO: no gate file updated in the last 2 hours. If you just completed a phase, sign off with the relevant template before starting the next." >&2
fi
exit 0
